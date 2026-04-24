#!/bin/bash

while true; do
    clear
    echo "=========================================="
    echo "        FlowCore Project Control Panel"
    echo "=========================================="
    echo ""
    echo "1) Full database rebuild"
    echo "2) Run inbound receiving flow"
    echo "3) Export validation report"
    echo "4) Cleanup environment"
    echo "5) View latest log/report"
    echo "6) Check database connection"
    echo "7) Run CSV tests"
    echo "8) Update master data"
    echo "9) Exit"
    echo ""
    read -p "Select option [1-9]: " choice

    case $choice in
        1)
            echo ""
            ./scripts/full_rebuild.sh
            read -p "Press Enter to continue..."
            ;;
        2)
            echo ""
            echo "Available C++ test files:"
            ls test_data/cpp*.csv 2>/dev/null
            echo ""

            read -p "Enter C++ test CSV [default: test_data/cpp_complex_full_outcome_coverage.csv]: " cpp_test_file

            if [ -z "$cpp_test_file" ]; then
                cpp_test_file="test_data/cpp_complex_full_outcome_coverage.csv"
            fi

            ./scripts/run_inbound_flow.sh "$cpp_test_file"

            read -p "Press Enter to continue..."
            ;;
        3)
            echo ""
            ./scripts/export_reports.sh
            read -p "Press Enter to continue..."
            ;;
        4)
            echo ""
            ./scripts/cleanup_environment.sh
            read -p "Press Enter to continue..."
            ;;
        5)
            echo ""
            echo "Latest log/report:"
            latest_file=$(ls -t logs/*.txt 2>/dev/null | head -n 1)

            if [ -z "$latest_file" ]; then
                echo "[INFO] No log files found."
            else
                echo "Opening: $latest_file"
                echo "------------------------------------------"
                cat "$latest_file"
            fi

            read -p "Press Enter to continue..."
            ;;
        6)
            echo ""
            source scripts/load_config.sh

            SQLPLUS_CMD="sqlplus -s ${DB_USER}/${DB_PASS}@//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"

            echo "Checking database connection..."
            echo "SELECT USER FROM dual;" | $SQLPLUS_CMD

            read -p "Press Enter to continue..."
            ;;
        7)
            echo ""
             echo "Available CSV test files:"
             ls test_data/receiving_tests_*.csv 2>/dev/null
            echo ""

            read -p "Enter CSV file path [default: test_data/receiving_tests_extended.csv]: " csv_file

            if [ -z "$csv_file" ]; then
                csv_file="test_data/receiving_tests_extended.csv"
            fi

            ./scripts/run_csv_tests.sh "$csv_file"

            read -p "Press Enter to continue..."
            ;;
        8)
            echo ""
            ./scripts/update_master_data.sh
            read -p "Press Enter to continue..."
            ;;
        9)
            echo "Exiting FlowCore Control Panel."
            exit 0
            ;;
        *)
            echo "Invalid option."
            read -p "Press Enter to continue..."
            ;;
    esac
done