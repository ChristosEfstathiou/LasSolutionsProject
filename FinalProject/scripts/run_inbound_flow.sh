#!/bin/bash

mkdir -p logs logs/cpp_deltas

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="logs/inbound_run_${TIMESTAMP}.txt"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================="
echo " FlowCore Inbound Receiving Automation"
echo "========================================="

source scripts/load_config.sh

SQLPLUS_CMD="sqlplus -s ${DB_USER}/${DB_PASS}@//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"

echo "[CONFIG] PREFER_SAME_PRODUCT_LOCATION=$PREFER_SAME_PRODUCT_LOCATION"
echo "[CONFIG] ALLOW_SPLIT_STORAGE=$ALLOW_SPLIT_STORAGE"
echo "[CONFIG] ENABLE_RECEIPT_LOGGING=$ENABLE_RECEIPT_LOGGING"
echo "[CONFIG] DEFAULT_RECEIPT_STATUS=$DEFAULT_RECEIPT_STATUS"

echo "[STEP 1] Checking database connection..."
echo "SELECT USER FROM dual;" | $SQLPLUS_CMD

if [ $? -ne 0 ]; then
    echo "[ERROR] Database connection failed."
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

CPP_TEST_FILE="${1}"
CPP_INPUT_FILE="logs/cpp_locations_from_db.csv"
CPP_WORK_FILE="logs/cpp_locations_working_${TIMESTAMP}.csv"
CPP_REPORT_FILE="logs/cpp_location_test_report_${TIMESTAMP}.txt"

if [ -z "$CPP_TEST_FILE" ]; then
    echo "[ERROR] No C++ test CSV provided."
    echo "Run from master_menu.sh or pass a CSV file manually."
    exit 1
fi

if [ ! -f "$CPP_TEST_FILE" ]; then
    echo "[ERROR] C++ test file not found: $CPP_TEST_FILE"
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

cat > "$CPP_REPORT_FILE" <<EOF
============================================================
 FLOWCORE - C++ + DB INBOUND TEST REPORT
============================================================

Generated at        : $(date)
Module              : C++ Location Allocator + Oracle Receiving
Test File           : $CPP_TEST_FILE
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

passed=0
failed=0
line_number=0

while IFS=',' read -r test_id product_id requires_refrigeration quantity expected_cpp_exit expected_db_status description || [ -n "$test_id" ]
do
    line_number=$((line_number + 1))

    if [ "$line_number" -eq 1 ]; then
        continue
    fi

    test_id=$(echo "$test_id" | tr -d '\r')
    product_id=$(echo "$product_id" | tr -d '\r')
    requires_refrigeration=$(echo "$requires_refrigeration" | tr -d '\r')
    quantity=$(echo "$quantity" | tr -d '\r')
    expected_cpp_exit=$(echo "$expected_cpp_exit" | tr -d '\r')
    expected_db_status=$(echo "$expected_db_status" | tr -d '\r')
    description=$(echo "$description" | tr -d '\r')

    if [ -z "$test_id" ]; then
        continue
    fi

    echo "[INFO] Running test $test_id..."

    BEFORE_RECEIPT_ID=$(echo "SET HEADING OFF FEEDBACK OFF VERIFY OFF;
    SELECT NVL(MAX(receipt_id), 0) FROM receipts;
    EXIT;" | $SQLPLUS_CMD | tr -d '[:space:]')

    BEFORE_EVENT_ID=$(echo "SET HEADING OFF FEEDBACK OFF VERIFY OFF;
    SELECT NVL(MAX(event_id), 0) FROM event_log;
    EXIT;" | $SQLPLUS_CMD | tr -d '[:space:]')

    cp "$CPP_WORK_FILE" "${CPP_WORK_FILE}.bak"

    # Validate that the CSV refrigeration flag matches the product master data in Oracle before attempting allocation. If there's a mismatch, skip the test and log it for manual review.
    refrigeration_check=$($SQLPLUS_CMD @sql/check_product_refrigeration.sql \
    "$product_id" \
    "$requires_refrigeration" | tr -d '[:space:]')

    if [ "$refrigeration_check" = "MISMATCH" ]; then
        output="ERROR: CSV refrigeration flag does not match product master data. Skipped for manual correction."
        actual_cpp_exit=1
        actual_db_status="SKIPPED"
        db_output="DB update skipped because refrigeration flag mismatch was detected before allocation."
    else
        output=$(./cpp/location_allocator \
            "$product_id" \
            "$requires_refrigeration" \
            "$quantity" \
            "$CPP_WORK_FILE" \
            "Y" \
            "$PREFER_SAME_PRODUCT_LOCATION" 2>&1)

        actual_cpp_exit=$?

        actual_db_status="SKIPPED"
        db_output=""

        if [ "$actual_cpp_exit" -eq 0 ]; then
            echo "[INFO] Updating Oracle DB for $test_id..."

            db_output=$($SQLPLUS_CMD @sql/process_receipt_from_cli.sql \
                "$product_id" \
                "$quantity" \
                "$DEFAULT_RECEIPT_STATUS" \
                "$PREFER_SAME_PRODUCT_LOCATION")

            actual_db_status=$(echo "$db_output" | grep "DB_STATUS=" | cut -d'=' -f2 | tr -d '[:space:]')

            if [ -z "$actual_db_status" ]; then
                actual_db_status="UNKNOWN"
            fi
        else
            db_output="DB update skipped because C++ allocation/input was not successful."
        fi

        # If C++ updated the working CSV but Oracle rejected the transaction, restore the previous CSV state so C++ and DB remain synchronized.
        if [ "$actual_cpp_exit" -eq 0 ] && [ "$actual_db_status" != "PROCESSED" ]; then
            echo "[INFO] Rolling back C++ working CSV state for $test_id because DB status is $actual_db_status."
            cp "${CPP_WORK_FILE}.bak" "$CPP_WORK_FILE"
        fi
    fi
    
    rm -f "${CPP_WORK_FILE}.bak"

    if [ "$actual_cpp_exit" -eq "$expected_cpp_exit" ] && [ "$actual_db_status" = "$expected_db_status" ]; then
        result="PASS"
        passed=$((passed + 1))
    else
        result="FAIL"
        failed=$((failed + 1))
    fi

    echo "$test_id | $result | CPP $expected_cpp_exit/$actual_cpp_exit | DB $expected_db_status/$actual_db_status | $output" >> "$CPP_REPORT_FILE"

    CPP_DELTA_FILE="logs/cpp_deltas/${test_id}_cpp_delta_${TIMESTAMP}.txt"

    {
        echo "============================================================"
        echo " FLOWCORE - C++ + DB TEST DELTA LOG"
        echo "============================================================"
        echo ""
        echo "Generated at        : $(date)"
        echo "Test ID             : $test_id"
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
        echo "DB Export CSV       : $CPP_INPUT_FILE"
        echo "Working CSV         : $CPP_WORK_FILE"
        echo ""
        echo "Expected / Actual"
        echo "------------------------------------------------------------"
        echo "Expected C++ exit   : $expected_cpp_exit"
        echo "Actual C++ exit     : $actual_cpp_exit"
        echo "Expected DB status  : $expected_db_status"
        echo "Actual DB status    : $actual_db_status"
        echo "Final Result        : $result"
        echo ""
        echo "C++ Output"
        echo "------------------------------------------------------------"
        echo "$output"
        echo ""
        echo "DB Output"
        echo "------------------------------------------------------------"
        echo "$db_output"
        echo ""
        echo "Working Location State After This Test"
        echo "------------------------------------------------------------"
        cat "$CPP_WORK_FILE"
        echo ""
        echo "Oracle Delta Snapshot After This Test"
        echo "------------------------------------------------------------"

        $SQLPLUS_CMD @sql/export_test_delta.sql \
            "$BEFORE_RECEIPT_ID" \
            "$BEFORE_EVENT_ID"

        echo ""
        echo "============================================================"
        echo " END OF DELTA LOG"
        echo "============================================================"
    } > "$CPP_DELTA_FILE"

    echo "[INFO] Delta log created: $CPP_DELTA_FILE"

done < "$CPP_TEST_FILE"

cat >> "$CPP_REPORT_FILE" <<EOF

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

cat "$CPP_REPORT_FILE"

if [ "$failed" -ne 0 ]; then
    echo "[ERROR] One or more tests failed."
    exit 1
fi

echo ""
echo "[STEP 4] Exporting final validation report..."
./scripts/export_reports.sh

if [ $? -ne 0 ]; then
    echo "[ERROR] Final report export failed."
    exit 1
fi

echo ""
echo "[DONE] Inbound flow completed successfully."
echo "Finished: $(date)"
echo "Main log saved to: $LOG_FILE"
echo "C++ report saved to: $CPP_REPORT_FILE"
echo "Working C++ state saved to: $CPP_WORK_FILE"