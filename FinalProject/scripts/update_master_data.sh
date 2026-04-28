#!/bin/bash

echo "=========================================="
echo " FlowCore Master Data Update"
echo "=========================================="

source scripts/load_config.sh

PRODUCT_FILE="data/updated_products.csv"
LOCATION_FILE="data/updated_locations.csv"

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

if [ ! -f "$PRODUCT_FILE" ]; then
    echo "[ERROR] Missing $PRODUCT_FILE"
    exit 1
fi

if [ ! -f "$LOCATION_FILE" ]; then
    echo "[ERROR] Missing $LOCATION_FILE"
    exit 1
fi

echo "[STEP 1] Adding new products only..."

line_number=0

while IFS=',' read -r product_id product_name requires_refrigeration unit_of_measure || [ -n "$product_id" ]
do
    line_number=$((line_number + 1))

    if [ "$line_number" -eq 1 ]; then
        continue
    fi

    product_id=$(echo "$product_id" | tr -d '\r')
    product_name=$(echo "$product_name" | tr -d '\r')
    requires_refrigeration=$(echo "$requires_refrigeration" | tr -d '\r')
    unit_of_measure=$(echo "$unit_of_measure" | tr -d '\r')

    if [ -z "$product_id" ]; then
        continue
    fi

$SQLPLUS_CMD <<EOF
SET SERVEROUTPUT ON
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM products
    WHERE product_id = $product_id;

    IF v_count = 0 THEN
        INSERT INTO products (
            product_id,
            product_name,
            requires_refrigeration,
            unit_of_measure
        )
        VALUES (
            $product_id,
            '$product_name',
            '$requires_refrigeration',
            '$unit_of_measure'
        );

        DBMS_OUTPUT.PUT_LINE('ADDED PRODUCT: $product_id - $product_name');
    ELSE
        DBMS_OUTPUT.PUT_LINE('SKIPPED EXISTING PRODUCT: $product_id');
    END IF;

    COMMIT;
END;
/
EXIT;
EOF

done < "$PRODUCT_FILE"

echo "[STEP 2] Adding/updating locations safely..."

line_number=0

while IFS=',' read -r location_id location_code zone is_refrigerated capacity used_capacity || [ -n "$location_id" ]
do
    line_number=$((line_number + 1))

    if [ "$line_number" -eq 1 ]; then
        continue
    fi

    location_id=$(echo "$location_id" | tr -d '\r')
    location_code=$(echo "$location_code" | tr -d '\r')
    zone=$(echo "$zone" | tr -d '\r')
    is_refrigerated=$(echo "$is_refrigerated" | tr -d '\r')
    capacity=$(echo "$capacity" | tr -d '\r')
    used_capacity=$(echo "$used_capacity" | tr -d '\r')

    if [ -z "$location_id" ]; then
        continue
    fi

$SQLPLUS_CMD <<EOF
SET SERVEROUTPUT ON
DECLARE
    v_count NUMBER;
    v_current_type CHAR(1);
    v_current_capacity NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM locations
    WHERE location_id = $location_id;

    IF v_count = 0 THEN
        INSERT INTO locations (
            location_id,
            location_code,
            zone,
            is_refrigerated,
            capacity,
            used_capacity
        )
        VALUES (
            $location_id,
            '$location_code',
            '$zone',
            '$is_refrigerated',
            $capacity,
            0
        );

        DBMS_OUTPUT.PUT_LINE('ADDED LOCATION: $location_id - $location_code');

    ELSE
        SELECT is_refrigerated, capacity
        INTO v_current_type, v_current_capacity
        FROM locations
        WHERE location_id = $location_id;

        IF v_current_type <> '$is_refrigerated' THEN
            DBMS_OUTPUT.PUT_LINE('REJECTED LOCATION UPDATE: $location_id type change is not allowed');

        ELSIF $capacity < v_current_capacity THEN
            DBMS_OUTPUT.PUT_LINE('REJECTED LOCATION UPDATE: $location_id capacity decrease is not allowed');

        ELSIF $capacity = v_current_capacity THEN
            DBMS_OUTPUT.PUT_LINE('SKIPPED LOCATION: $location_id capacity unchanged');

        ELSE
            UPDATE locations
            SET capacity = $capacity
            WHERE location_id = $location_id;

            DBMS_OUTPUT.PUT_LINE('UPDATED LOCATION CAPACITY: $location_id from ' || v_current_capacity || ' to ' || $capacity);
        END IF;
    END IF;

    COMMIT;
END;
/
EXIT;
EOF

done < "$LOCATION_FILE"

echo ""
echo "[STEP 3] Current locations after update..."
echo ""

$SQLPLUS_CMD <<EOF
SET PAGESIZE 100
SET LINESIZE 180
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
SET UNDERLINE =
SET TRIMSPOOL ON

COLUMN location_id FORMAT 999
COLUMN location_code FORMAT A12
COLUMN zone FORMAT A18
COLUMN type FORMAT A15
COLUMN capacity FORMAT 9999
COLUMN used_capacity FORMAT 9999
COLUMN free_capacity FORMAT 9999

SELECT
    location_id,
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

EXIT;
EOF

echo ""
echo "[STEP 4] Current products after update..."
echo ""

$SQLPLUS_CMD <<EOF
SET PAGESIZE 100
SET LINESIZE 180
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
SET UNDERLINE =
SET TRIMSPOOL ON

COLUMN product_id FORMAT 999
COLUMN product_name FORMAT A25
COLUMN storage_type FORMAT A15
COLUMN unit_of_measure FORMAT A12

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

EXIT;
EOF

echo ""
echo "[DONE] Master data update completed."