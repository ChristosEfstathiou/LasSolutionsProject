#!/bin/bash

mkdir -p logs

source scripts/load_config.sh

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
REPORT_FILE="logs/inbound_validation_report_${TIMESTAMP}.txt"

SQLPLUS_CMD="sqlplus -L -s ${DB_USER}/${DB_PASS}@//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"

echo ""
echo "Checking database connection..."

$SQLPLUS_CMD <<EOF
WHENEVER OSERROR EXIT 1
WHENEVER SQLERROR EXIT SQL.SQLCODE
SELECT USER FROM dual;
EXIT;
EOF

if [ $? -ne 0 ]; then
    echo "[ERROR] Database connection failed."
    echo "[ERROR] Please check that Docker Desktop is running and the Oracle container is started."
    echo "[ERROR] You can start it with: docker start oracle-db"
    exit 1
fi

cat > "$REPORT_FILE" <<EOF
============================================================
 FLOWCORE - INBOUND RECEIVING VALIDATION REPORT
============================================================

Generated at: $TIMESTAMP
Environment : Local Docker Oracle DB
Schema      : WAREHOUSE
Module      : Receiving / Putaway / Inventory Update

============================================================
EOF

$SQLPLUS_CMD <<EOF >> "$REPORT_FILE"

SET PAGESIZE 100
SET LINESIZE 180
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
SET UNDERLINE =
SET TRIMSPOOL ON
SET TAB OFF

PROMPT
PROMPT ============================================================
PROMPT 1. RECEIPT STATUS SUMMARY
PROMPT ============================================================

COLUMN receipt_id FORMAT 999
COLUMN supplier_name FORMAT A25
COLUMN status FORMAT A15
COLUMN receipt_date FORMAT A20

SELECT
    receipt_id,
    supplier_name,
    TO_CHAR(receipt_date, 'YYYY-MM-DD HH24:MI') AS receipt_date,
    status
FROM receipts
ORDER BY receipt_id;

PROMPT
PROMPT ============================================================
PROMPT 1B. RECEIPT LINES FOR LATEST RECEIPT
PROMPT ============================================================

COLUMN receipt_line_id FORMAT 9999
COLUMN receipt_id FORMAT 9999
COLUMN product_name FORMAT A20
COLUMN quantity FORMAT 9999

SELECT
    rl.receipt_line_id,
    rl.receipt_id,
    p.product_name,
    rl.quantity
FROM receipt_lines rl
JOIN products p ON p.product_id = rl.product_id
WHERE rl.receipt_id = (
    SELECT MAX(receipt_id)
    FROM receipts
)
ORDER BY rl.receipt_line_id;

PROMPT
PROMPT ============================================================
PROMPT 2. CURRENT INVENTORY BY LOCATION
PROMPT ============================================================

COLUMN product_name FORMAT A20
COLUMN location_code FORMAT A15
COLUMN storage_type FORMAT A15
COLUMN quantity FORMAT 9999

SELECT
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
PROMPT 3. LOCATION CAPACITY CHECK
PROMPT ============================================================

COLUMN location_code FORMAT A15
COLUMN zone FORMAT A20
COLUMN type FORMAT A15
COLUMN capacity FORMAT 9999
COLUMN used_capacity FORMAT 9999
COLUMN free_capacity FORMAT 9999

SELECT
    location_code,
    zone,
    CASE
        WHEN is_refrigerated = 'Y' THEN 'REFRIGERATED'
        ELSE 'DRY'
    END AS type,
    capacity,
    used_capacity,
    capacity - used_capacity AS free_capacity
FROM locations
ORDER BY location_id;

PROMPT
PROMPT ============================================================
PROMPT 4. EVENT LOG FOR LATEST RECEIPT RUN
PROMPT ============================================================

COLUMN event_id FORMAT 9999
COLUMN event_type FORMAT A25
COLUMN reference_type FORMAT A15
COLUMN reference_id FORMAT 9999
COLUMN message FORMAT A100

WITH latest_receipt AS (
    SELECT MAX(receipt_id) AS receipt_id
    FROM receipts
),
latest_receipt_start AS (
    SELECT MIN(event_id) AS start_event_id
    FROM event_log e
    JOIN latest_receipt lr
      ON e.reference_id = lr.receipt_id
    WHERE e.reference_type = 'RECEIPT'
),
previous_receipt_event AS (
    SELECT NVL(MAX(event_id), 0) AS previous_event_id
    FROM event_log
    WHERE event_id < (
        SELECT start_event_id
        FROM latest_receipt_start
    )
    AND reference_type = 'RECEIPT'
)
SELECT
    e.event_id,
    e.event_type,
    e.reference_type,
    e.reference_id,
    e.message
FROM event_log e
WHERE e.event_id > (
        SELECT previous_event_id
        FROM previous_receipt_event
    )
  AND (
        e.event_type = 'RECEIPT_LINE_SKIPPED'
        OR (
            e.reference_type = 'RECEIPT'
            AND e.reference_id = (
                SELECT receipt_id
                FROM latest_receipt
            )
        )
      )
ORDER BY e.event_id;

PROMPT
PROMPT ============================================================
PROMPT 5. VALIDATION CHECKS
PROMPT ============================================================

PROMPT Check 1: Locations over capacity
SELECT COUNT(*) AS over_capacity_locations
FROM locations
WHERE used_capacity > capacity;

PROMPT
PROMPT Check 2: Inventory stored in wrong temperature location
SELECT COUNT(*) AS wrong_temperature_records
FROM inventory i
JOIN products p ON p.product_id = i.product_id
JOIN locations l ON l.location_id = i.location_id
WHERE p.requires_refrigeration <> l.is_refrigerated;

PROMPT
PROMPT Check 3: Failed receipts
SELECT COUNT(*) AS failed_receipts
FROM receipts
WHERE status = 'FAILED';

PROMPT
PROMPT ============================================================
PROMPT END OF REPORT
PROMPT ============================================================

EXIT;
EOF

echo "[DONE] Clean validation report exported to:"
echo "$REPORT_FILE"