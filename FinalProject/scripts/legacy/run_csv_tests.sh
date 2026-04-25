#!/bin/bash

mkdir -p logs

source scripts/load_config.sh

CSV_FILE="${1:-data/receiving_tests_extended.csv}"

if [ ! -f "$CSV_FILE" ]; then
    echo "[ERROR] CSV file not found: $CSV_FILE"
    echo "Usage: ./scripts/legacy/run_csv_tests.sh [csv_file]"
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="logs/receiving_csv_test_report_${TIMESTAMP}.txt"

SQLPLUS_CMD="sqlplus -s ${DB_USER}/${DB_PASS}@//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"

cat > "$REPORT_FILE" <<EOF
============================================================
 FLOWCORE - RECEIVING CSV TEST REPORT
============================================================

Generated at: $(date)
Module      : Inbound Receiving / Putaway
Input File  : $CSV_FILE

============================================================

TEST ID  | RESULT | EXPECTED     | ACTUAL       | DESCRIPTION
------------------------------------------------------------
EOF
get_max_receipt_id() {
    echo "SET HEADING OFF FEEDBACK OFF VERIFY OFF;
SELECT NVL(MAX(receipt_id), 0) FROM receipts;
EXIT;" | $SQLPLUS_CMD | tr -d '[:space:]'
}

get_max_event_id() {
    echo "SET HEADING OFF FEEDBACK OFF VERIFY OFF;
SELECT NVL(MAX(event_id), 0) FROM event_log;
EXIT;" | $SQLPLUS_CMD | tr -d '[:space:]'
}
line_number=0

while IFS=',' read -r test_id product_id quantity expected_status description || [ -n "$test_id" ]
do
    line_number=$((line_number + 1))

    # Skip header
    if [ "$line_number" -eq 1 ]; then
        continue
    fi

    # Clean Windows carriage returns
    test_id=$(echo "$test_id" | tr -d '\r')
    product_id=$(echo "$product_id" | tr -d '\r')
    quantity=$(echo "$quantity" | tr -d '\r')
    expected_status=$(echo "$expected_status" | tr -d '\r')
    description=$(echo "$description" | tr -d '\r')

    # Skip empty lines
    if [ -z "$test_id" ]; then
        continue
    fi

    echo "[INFO] Running $test_id..."

    mkdir -p logs/deltas

    BEFORE_RECEIPT_ID=$(get_max_receipt_id)
    BEFORE_EVENT_ID=$(get_max_event_id)

    $SQLPLUS_CMD @sql/run_single_receiving_test.sql \
        "$test_id" \
        "$product_id" \
        "$quantity" \
        "$expected_status" \
        "$description" >> "$REPORT_FILE"

    DELTA_FILE="logs/deltas/${test_id}_delta_${TIMESTAMP}.txt"

    {
        echo "============================================================"
        echo " FLOWCORE - TEST DELTA SNAPSHOT"
        echo "============================================================"
        echo ""
        echo "Generated at : $(date)"
        echo "Test ID      : $test_id"
        echo "Description  : $description"
        echo "Input        : product_id=$product_id, quantity=$quantity"
        echo "Expected     : $expected_status"
        echo ""
        echo "Before receipt_id max: $BEFORE_RECEIPT_ID"
        echo "Before event_id max  : $BEFORE_EVENT_ID"
        echo ""
        echo "============================================================"
    } > "$DELTA_FILE"

    $SQLPLUS_CMD @sql/export_test_delta.sql \
        "$BEFORE_RECEIPT_ID" \
        "$BEFORE_EVENT_ID" >> "$DELTA_FILE"

    echo "[INFO] Delta snapshot created: $DELTA_FILE"

done < "$CSV_FILE"

PASSED=$(grep -E "^[A-Z]+[0-9]+[[:space:]]*\| PASS" "$REPORT_FILE" | wc -l)
FAILED=$(grep -E "^[A-Z]+[0-9]+[[:space:]]*\| FAIL" "$REPORT_FILE" | wc -l)
TOTAL=$((PASSED + FAILED))

cat >> "$REPORT_FILE" <<EOF

============================================================
 SUMMARY
============================================================
Total Tests : $TOTAL
Passed      : $PASSED
Failed      : $FAILED

============================================================
 END OF TEST REPORT
============================================================
EOF

echo "[DONE] CSV test report created:"
echo "$REPORT_FILE"