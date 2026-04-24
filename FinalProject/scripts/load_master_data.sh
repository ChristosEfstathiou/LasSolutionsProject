#!/bin/bash

echo "=========================================="
echo " FlowCore Master Data Loader"
echo "=========================================="

source scripts/load_config.sh

SQLPLUS_CMD="sqlplus -s ${DB_USER}/${DB_PASS}@//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"

PRODUCT_FILE="data/products.csv"
LOCATION_FILE="data/locations.csv"

if [ ! -f "$PRODUCT_FILE" ]; then
    echo "[ERROR] Missing $PRODUCT_FILE"
    exit 1
fi

if [ ! -f "$LOCATION_FILE" ]; then
    echo "[ERROR] Missing $LOCATION_FILE"
    exit 1
fi

echo "[STEP 1] Clearing existing master data..."

$SQLPLUS_CMD <<EOF
DELETE FROM inventory;
DELETE FROM locations;
DELETE FROM products;
COMMIT;
EXIT;
EOF

echo "[STEP 2] Loading products..."

tail -n +2 "$PRODUCT_FILE" | while IFS=',' read -r product_id product_name requires_refrigeration unit_of_measure
do
$SQLPLUS_CMD <<EOF
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
COMMIT;
EXIT;
EOF
done

echo "[STEP 3] Loading locations..."

tail -n +2 "$LOCATION_FILE" | while IFS=',' read -r location_id location_code zone is_refrigerated capacity used_capacity
do
$SQLPLUS_CMD <<EOF
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
    $used_capacity
);
COMMIT;
EXIT;
EOF
done

echo "[DONE] Master data loaded successfully."