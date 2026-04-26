#!/bin/bash

source scripts/load_config.sh

mkdir -p logs

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
STATUS_FILE="logs/current_status_snapshot_${TIMESTAMP}.txt"

SQLPLUS_CMD="sqlplus -L -s ${DB_USER}/${DB_PASS}@//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"

$SQLPLUS_CMD <<EOF > "$STATUS_FILE"
SET PAGESIZE 100
SET LINESIZE 220
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
SET UNDERLINE =
SET TRIMSPOOL ON
SET TAB OFF

COLUMN product_id FORMAT 999
COLUMN product_name FORMAT A25
COLUMN storage_type FORMAT A15
COLUMN unit_of_measure FORMAT A12

COLUMN location_id FORMAT 999
COLUMN location_code FORMAT A15
COLUMN zone FORMAT A18
COLUMN capacity FORMAT 9999
COLUMN used_capacity FORMAT 9999
COLUMN free_capacity FORMAT 9999
COLUMN product_ids FORMAT A25

COLUMN inventory_id FORMAT 9999
COLUMN quantity FORMAT 9999

PROMPT ============================================================
PROMPT FLOWCORE CURRENT STATUS SNAPSHOT
PROMPT ============================================================
PROMPT Generated at: $TIMESTAMP
PROMPT

PROMPT ============================================================
PROMPT PRODUCTS
PROMPT ============================================================

SELECT
    product_id,
    product_name,
    CASE
        WHEN requires_refrigeration = 'Y' THEN 'REFRIGERATED'
        ELSE 'DRY'
    END AS storage_type,
    unit_of_measure
FROM products
ORDER BY product_id;

PROMPT
PROMPT ============================================================
PROMPT LOCATIONS
PROMPT ============================================================

SELECT
    l.location_id,
    l.location_code,
    l.zone,
    CASE
        WHEN l.is_refrigerated = 'Y' THEN 'REFRIGERATED'
        ELSE 'DRY'
    END AS storage_type,
    l.capacity,
    l.used_capacity,
    l.capacity - l.used_capacity AS free_capacity,
    NVL((
        SELECT LISTAGG(i.product_id, '|')
        WITHIN GROUP (ORDER BY i.product_id)
        FROM inventory i
        WHERE i.location_id = l.location_id
    ), 'NONE') AS product_ids
FROM locations l
ORDER BY l.location_id;

PROMPT
PROMPT ============================================================
PROMPT INVENTORY
PROMPT ============================================================

SELECT
    i.inventory_id,
    p.product_name,
    l.location_code,
    CASE
        WHEN l.is_refrigerated = 'Y' THEN 'REFRIGERATED'
        ELSE 'DRY'
    END AS storage_type,
    i.quantity
FROM inventory i
JOIN products p ON p.product_id = i.product_id
JOIN locations l ON l.location_id = i.location_id
ORDER BY p.product_name, l.location_code;

PROMPT
PROMPT ============================================================
PROMPT END OF SNAPSHOT
PROMPT ============================================================

EXIT;
EOF

echo "[DONE] Current status snapshot created:"
echo "$STATUS_FILE"
echo "------------------------------------------"
cat "$STATUS_FILE"