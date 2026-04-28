#!/bin/bash

mkdir -p logs logs/cpp_deltas

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="logs/inbound_multi_product_run_${TIMESTAMP}.txt"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=============================================="
echo " FlowCore Multi-Product Receipt Inbound Flow"
echo "=============================================="

source scripts/load_config.sh

# ------------------------------------------------------------
# Validate configuration values
# ------------------------------------------------------------

if [[ "$PREFER_SAME_PRODUCT_LOCATION" != "Y" && "$PREFER_SAME_PRODUCT_LOCATION" != "N" ]]; then
    echo "[ERROR] Invalid PREFER_SAME_PRODUCT_LOCATION value: $PREFER_SAME_PRODUCT_LOCATION"
    echo "[ERROR] Allowed values: Y or N"
    echo "[ERROR] Please correct the value in config/receiving.conf and re-run."
    exit 1
fi

if [[ "$ALLOW_SPLIT_STORAGE" != "Y" && "$ALLOW_SPLIT_STORAGE" != "N" ]]; then
    echo "[ERROR] Invalid ALLOW_SPLIT_STORAGE value: $ALLOW_SPLIT_STORAGE"
    echo "[ERROR] Allowed values: Y or N"
    echo "[ERROR] Please correct the value in config/receiving.conf and re-run."
    exit 1
fi

if [[ "$ENABLE_RECEIPT_LOGGING" != "Y" && "$ENABLE_RECEIPT_LOGGING" != "N" ]]; then
    echo "[ERROR] Invalid ENABLE_RECEIPT_LOGGING value: $ENABLE_RECEIPT_LOGGING"
    echo "[ERROR] Allowed values: Y or N"
    echo "[ERROR] Please correct the value in config/receiving.conf and re-run."
    exit 1
fi

if [[ "$DEFAULT_RECEIPT_STATUS" != "RECEIVED" ]]; then
    echo "[ERROR] Invalid DEFAULT_RECEIPT_STATUS value: $DEFAULT_RECEIPT_STATUS"
    echo "[ERROR] Current allowed value: RECEIVED"
    echo "[ERROR] Please correct the value in config/receiving.conf and re-run."
    exit 1
fi

SQLPLUS_CMD="sqlplus -L -s ${DB_USER}/${DB_PASS}@//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"

echo "[CONFIG] PREFER_SAME_PRODUCT_LOCATION=$PREFER_SAME_PRODUCT_LOCATION"
echo "[CONFIG] ALLOW_SPLIT_STORAGE=$ALLOW_SPLIT_STORAGE"
echo "[CONFIG] ENABLE_RECEIPT_LOGGING=$ENABLE_RECEIPT_LOGGING"
echo "[CONFIG] DEFAULT_RECEIPT_STATUS=$DEFAULT_RECEIPT_STATUS"

# ------------------------------------------------------------
# Environment checks
# ------------------------------------------------------------

echo ""
echo "[STEP 1] Checking database connection..."

$SQLPLUS_CMD <<EOF
WHENEVER OSERROR EXIT 1
WHENEVER SQLERROR EXIT SQL.SQLCODE
SELECT USER FROM dual;
EXIT;
EOF

if [ $? -ne 0 ]; then
    echo "[ERROR] Database connection failed."
    echo "[ERROR] Please check that Docker Desktop is running and the Oracle container is started."
    exit 1
fi

echo "[STEP 2] Compiling C++ location allocator..."
g++ cpp/location_allocator.cpp -o cpp/location_allocator

if [ $? -ne 0 ]; then
    echo "[ERROR] C++ compilation failed."
    exit 1
fi

echo "[STEP 3] Exporting current DB location state for C++..."

# Export current Oracle warehouse location state to CSV for the C++ allocator
$SQLPLUS_CMD @sql/export_locations_for_cpp.sql

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to export DB location state."
    exit 1
fi

# ------------------------------------------------------------
# Prepare input and output files
# ------------------------------------------------------------

CSV_FILE="$1"

if [ -z "$CSV_FILE" ]; then
    echo "[ERROR] No multi-product receipt CSV provided."
    echo "Run from master_menu.sh or pass a CSV file manually."
    exit 1
fi

CPP_INPUT_FILE="logs/cpp_locations_from_db.csv"
CPP_WORK_FILE="logs/cpp_locations_working_multi_${TIMESTAMP}.csv"
REPORT_FILE="logs/multi_product_receipt_report_${TIMESTAMP}.txt"

if [ ! -f "$CSV_FILE" ]; then
    echo "[ERROR] Multi-product receipt CSV not found: $CSV_FILE"
    exit 1
fi

if [ ! -f "$CPP_INPUT_FILE" ]; then
    echo "[ERROR] Expected export file was not created: $CPP_INPUT_FILE"
    echo "[ERROR] Check export_locations_for_cpp.sql execution."
    exit 1
fi

if [ ! -s "$CPP_INPUT_FILE" ]; then
    echo "[ERROR] Export file is missing or empty: $CPP_INPUT_FILE"
    exit 1
fi

cp "$CPP_INPUT_FILE" "$CPP_WORK_FILE"

cat > "$REPORT_FILE" <<EOF
============================================================
 FLOWCORE - MULTI-PRODUCT RECEIPT TEST REPORT
============================================================

Generated at        : $(date)
Module              : Multi-Product Receipt Inbound Flow
Input CSV           : $CSV_FILE
DB Export File      : $CPP_INPUT_FILE
Working State File  : $CPP_WORK_FILE

Configuration:
PREFER_SAME_PRODUCT_LOCATION = $PREFER_SAME_PRODUCT_LOCATION
ALLOW_SPLIT_STORAGE          = $ALLOW_SPLIT_STORAGE
ENABLE_RECEIPT_LOGGING       = $ENABLE_RECEIPT_LOGGING
DEFAULT_RECEIPT_STATUS       = $DEFAULT_RECEIPT_STATUS

============================================================

TEST ID | RESULT | CPP EXPECTED/ACTUAL | DB EXPECTED/ACTUAL | OUTPUT
---------------------------------------------------------------------
EOF

# ------------------------------------------------------------
# Prepare staging table
# ------------------------------------------------------------

echo "[STEP 4] Preparing temporary receipt-line staging table..."

$SQLPLUS_CMD <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE temp_multi_product_receipt_lines';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/

CREATE TABLE temp_multi_product_receipt_lines (
    line_no NUMBER,
    product_id NUMBER,
    quantity NUMBER
);

EXIT;
EOF

if [ $? -ne 0 ]; then
    echo "[ERROR] Could not prepare temporary staging table."
    exit 1
fi

# ------------------------------------------------------------
# Capture DB state before receipt processing
# ------------------------------------------------------------

BEFORE_RECEIPT_ID=$(echo "SET HEADING OFF FEEDBACK OFF VERIFY OFF;
SELECT NVL(MAX(receipt_id), 0) FROM receipts;
EXIT;" | $SQLPLUS_CMD | tr -d '[:space:]')

BEFORE_EVENT_ID=$(echo "SET HEADING OFF FEEDBACK OFF VERIFY OFF;
SELECT NVL(MAX(event_id), 0) FROM event_log;
EXIT;" | $SQLPLUS_CMD | tr -d '[:space:]')

# Backup working CSV before the whole receipt
cp "$CPP_WORK_FILE" "${CPP_WORK_FILE}.bak"

# ------------------------------------------------------------
# Validate CSV lines through C++ and stage successful lines
# ------------------------------------------------------------

echo "[STEP 5] Validating receipt lines with C++ allocator..."

passed=0
failed=0
line_number=0
line_no=0
supplier_name=""
has_cpp_success="N"

test_ids=()
product_ids=()
refrigeration_flags=()
quantities=()
expected_cpp_values=()
expected_db_values=()
actual_cpp_values=()
outputs=()
descriptions=()

while IFS=',' read -r test_id supplier_name_csv product_id requires_refrigeration quantity expected_cpp_exit expected_db_status description || [ -n "$test_id" ]
do
    line_number=$((line_number + 1))

    if [ "$line_number" -eq 1 ]; then
        continue
    fi

    test_id=$(echo "$test_id" | tr -d '\r')
    supplier_name_csv=$(echo "$supplier_name_csv" | tr -d '\r')
    product_id=$(echo "$product_id" | tr -d '\r')
    requires_refrigeration=$(echo "$requires_refrigeration" | tr -d '\r')
    quantity=$(echo "$quantity" | tr -d '\r')
    expected_cpp_exit=$(echo "$expected_cpp_exit" | tr -d '\r')
    expected_db_status=$(echo "$expected_db_status" | tr -d '\r')
    description=$(echo "$description" | tr -d '\r')

    if [ -z "$test_id" ]; then
        continue
    fi

    if [ -z "$supplier_name" ]; then
        supplier_name="$supplier_name_csv"
    fi

    echo "[INFO] Validating receipt line $test_id..."

    product_check=$($SQLPLUS_CMD @sql/check_product_exists.sql \
    "$product_id" | tr -d '[:space:]')

    # Validate that the product exists in Oracle before running C++
    product_check=$($SQLPLUS_CMD @sql/check_product_exists.sql \
        "$product_id" | tr -d '[:space:]')

    if [ "$product_check" = "NOT_FOUND" ]; then
        output="ERROR: Product ID does not exist in Oracle master data. Skipped before allocation."
        actual_cpp_exit=1
    else
        refrigeration_check=$($SQLPLUS_CMD @sql/check_product_refrigeration.sql \
            "$product_id" \
            "$requires_refrigeration" | tr -d '[:space:]')

        if [ "$refrigeration_check" = "MISMATCH" ]; then
            output="ERROR: CSV refrigeration flag does not match product master data. Skipped for manual correction."
            actual_cpp_exit=1
        else
            output=$(./cpp/location_allocator \
                "$product_id" \
                "$requires_refrigeration" \
                "$quantity" \
                "$CPP_WORK_FILE" \
                "Y" \
                "$PREFER_SAME_PRODUCT_LOCATION" 2>&1)

            actual_cpp_exit=$?
        fi
    fi

    # ============================================================
    # Log every skipped / rejected line into Oracle event_log
    # ============================================================
    if [ "$actual_cpp_exit" -ne 0 ]; then
        safe_output=$(echo "$output" | sed "s/'/''/g")
        safe_description=$(echo "$description" | sed "s/'/''/g")

        $SQLPLUS_CMD <<EOF
BEGIN
    log_event(
        'RECEIPT_LINE_SKIPPED',
        'CSV_TEST',
        0,
        'Test ID $test_id skipped before receipt processing. Product ID: $product_id, Quantity: $quantity, Reason: $safe_output. Description: $safe_description'
    );

    COMMIT;
END;
/
EXIT;
EOF
fi

    test_ids+=("$test_id")
    product_ids+=("$product_id")
    refrigeration_flags+=("$requires_refrigeration")
    quantities+=("$quantity")
    expected_cpp_values+=("$expected_cpp_exit")
    expected_db_values+=("$expected_db_status")
    actual_cpp_values+=("$actual_cpp_exit")
    outputs+=("$output")
    descriptions+=("$description")

    if [ "$actual_cpp_exit" -eq 0 ]; then
        has_cpp_success="Y"
        line_no=$((line_no + 1))

        $SQLPLUS_CMD <<EOF
        INSERT INTO temp_multi_product_receipt_lines (
        line_no,
        product_id,
        quantity
    )
    VALUES (
        $line_no,
        $product_id,
        $quantity
);
    
COMMIT;
EXIT;
EOF
fi

LINE_DELTA_FILE="logs/cpp_deltas/${test_id}_line_delta_${TIMESTAMP}.txt"

{
    echo "============================================================"
    echo " FLOWCORE - MULTI-PRODUCT RECEIPT LINE DELTA LOG"
    echo "============================================================"
    echo ""
    echo "Generated at        : $(date)"
    echo "Test ID             : $test_id"
    echo "Supplier            : $supplier_name"
    echo "Product ID          : $product_id"
    echo "Description         : $description"
    echo ""
    echo "Configuration"
    echo "------------------------------------------------------------"
    echo "PREFER_SAME_PRODUCT_LOCATION = $PREFER_SAME_PRODUCT_LOCATION"
    echo "ALLOW_SPLIT_STORAGE          = $ALLOW_SPLIT_STORAGE"
    echo "ENABLE_RECEIPT_LOGGING       = $ENABLE_RECEIPT_LOGGING"
    echo "DEFAULT_RECEIPT_STATUS       = $DEFAULT_RECEIPT_STATUS"
    echo ""
    echo "Input Parameters"
    echo "------------------------------------------------------------"
    echo "Requires cold store : $requires_refrigeration"
    echo "Quantity            : $quantity"
    echo "Working CSV         : $CPP_WORK_FILE"
    echo ""
    echo "C++ Result"
    echo "------------------------------------------------------------"
    echo "Expected C++ exit   : $expected_cpp_exit"
    echo "Actual C++ exit     : $actual_cpp_exit"
    echo "C++ Output"
    echo "$output"
    echo ""
    echo "Working Location State After This Line"
    echo "------------------------------------------------------------"
    cat "$CPP_WORK_FILE"
    echo ""
    echo "Note"
    echo "------------------------------------------------------------"
    echo "This is a line-level C++ delta log."
    echo "Oracle DB updates are applied later when the full receipt is processed."
    echo ""
    echo "============================================================"
    echo " END OF LINE DELTA LOG"
    echo "============================================================"
} > "$LINE_DELTA_FILE"

echo "[INFO] Line delta log created: $LINE_DELTA_FILE"
    

done < "$CSV_FILE"

# ------------------------------------------------------------
# Process one Oracle receipt containing all staged lines
# ------------------------------------------------------------

echo "[STEP 6] Processing one Oracle receipt with all valid staged lines..."

db_output=$($SQLPLUS_CMD @sql/process_receipt_from_cli_multiple_products.sql \
    "$supplier_name" \
    "$DEFAULT_RECEIPT_STATUS" \
    "$PREFER_SAME_PRODUCT_LOCATION")

actual_db_status=$(echo "$db_output" | grep "DB_STATUS=" | cut -d'=' -f2 | tr -d '[:space:]')

if [ -z "$actual_db_status" ]; then
    actual_db_status="UNKNOWN"
fi

# If C++ updated the working CSV but Oracle rejected the transaction,
# restore the previous CSV state so C++ and DB remain synchronized.
if [ "$has_cpp_success" = "Y" ] && [ "$actual_db_status" != "PROCESSED" ]; then
    echo "[INFO] Rolling back C++ working CSV state because DB status is $actual_db_status."
    cp "${CPP_WORK_FILE}.bak" "$CPP_WORK_FILE"
fi

rm -f "${CPP_WORK_FILE}.bak"

# ------------------------------------------------------------
# Evaluate every CSV line and create delta logs
# ------------------------------------------------------------

echo "[STEP 7] Creating report and delta logs..."

for i in "${!test_ids[@]}"
do
    test_id="${test_ids[$i]}"
    product_id="${product_ids[$i]}"
    requires_refrigeration="${refrigeration_flags[$i]}"
    quantity="${quantities[$i]}"
    expected_cpp_exit="${expected_cpp_values[$i]}"
    expected_db_status="${expected_db_values[$i]}"
    actual_cpp_exit="${actual_cpp_values[$i]}"
    output="${outputs[$i]}"
    description="${descriptions[$i]}"

    if [ "$actual_cpp_exit" -eq 0 ]; then
        line_db_status="$actual_db_status"
    else
        line_db_status="SKIPPED"
    fi

    if [ "$actual_cpp_exit" -eq "$expected_cpp_exit" ] && [ "$line_db_status" = "$expected_db_status" ]; then
        result="PASS"
        passed=$((passed + 1))
    else
        result="FAIL"
        failed=$((failed + 1))
    fi

    echo "$test_id | $result | CPP $expected_cpp_exit/$actual_cpp_exit | DB $expected_db_status/$line_db_status | $output" >> "$REPORT_FILE"

    
done

RECEIPT_DELTA_FILE="logs/cpp_deltas/multi_product_receipt_db_delta_${TIMESTAMP}.txt"

{
    echo "============================================================"
    echo " FLOWCORE - MULTI-PRODUCT RECEIPT DB DELTA LOG"
    echo "============================================================"
    echo ""
    echo "Generated at        : $(date)"
    echo "Supplier            : $supplier_name"
    echo "Input CSV           : $CSV_FILE"
    echo ""
    echo "DB Output For Full Receipt"
    echo "------------------------------------------------------------"
    echo "$db_output"
    echo ""
    echo "Final Working Location State"
    echo "------------------------------------------------------------"
    cat "$CPP_WORK_FILE"
    echo ""
    echo "Oracle Delta Snapshot After Full Receipt"
    echo "------------------------------------------------------------"

    $SQLPLUS_CMD @sql/export_test_delta.sql \
        "$BEFORE_RECEIPT_ID" \
        "$BEFORE_EVENT_ID"

    echo ""
    echo "============================================================"
    echo " END OF RECEIPT DB DELTA LOG"
    echo "============================================================"
} > "$RECEIPT_DELTA_FILE"

echo "[INFO] Receipt DB delta log created: $RECEIPT_DELTA_FILE"

# ------------------------------------------------------------
# Cleanup staging table
# ------------------------------------------------------------

echo "[STEP 8] Cleaning temporary staging table..."

$SQLPLUS_CMD <<EOF
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE temp_multi_product_receipt_lines';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/
EXIT;
EOF

cat >> "$REPORT_FILE" <<EOF

============================================================
 SUMMARY
============================================================
Total Tests : $((passed + failed))
Passed      : $passed
Failed      : $failed

============================================================
 END OF TEST REPORT
============================================================
EOF

cat "$REPORT_FILE"

if [ "$failed" -ne 0 ]; then
    echo "[ERROR] One or more tests failed."
    exit 1
fi

echo ""
echo "[STEP 9] Exporting final validation report..."
./scripts/export_reports.sh

if [ $? -ne 0 ]; then
    echo "[ERROR] Final report export failed."
    exit 1
fi

echo ""
echo "[STEP 10] Cleaning temporary allocator files..."
rm -f "$CPP_INPUT_FILE"
rm -f "$CPP_WORK_FILE"

echo ""
echo "[DONE] Multi-product inbound flow completed successfully."
echo "Finished: $(date)"
echo "Main log saved to: $LOG_FILE"
echo "Report saved to: $REPORT_FILE"