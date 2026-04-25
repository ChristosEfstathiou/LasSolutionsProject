#!/bin/bash

echo "=========================================="
echo " FlowCore Environment Cleanup"
echo "=========================================="

source scripts/load_config.sh

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

echo "[STEP 1] Cleaning database data..."

$SQLPLUS_CMD <<EOF

SET SERVEROUTPUT ON
SET FEEDBACK OFF

BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE event_log';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE order_lines';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE customer_orders';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE receipt_lines';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE receipts';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE inventory';

    UPDATE locations
    SET used_capacity = 0;

    COMMIT;
END;
/
EXIT;
EOF

if [ $? -ne 0 ]; then
    echo "[ERROR] Database cleanup failed."
    exit 1
fi

echo "[STEP 2] Resetting sequences..."

$SQLPLUS_CMD <<EOF

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_inventory';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_inventory START WITH 1 INCREMENT BY 1';

    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_receipts';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_receipts START WITH 1 INCREMENT BY 1';

    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_receipt_lines';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_receipt_lines START WITH 1 INCREMENT BY 1';

    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_customer_orders';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_customer_orders START WITH 1 INCREMENT BY 1';

    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_order_lines';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_order_lines START WITH 1 INCREMENT BY 1';

    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_event_log';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_event_log START WITH 1 INCREMENT BY 1';
END;
/
EXIT;
EOF

echo "[STEP 3] Removing log files..."

rm -f logs/*.txt
rm -f logs/*.csv
rm -f logs/deltas/*.txt
rm -f logs/cpp_deltas/*.txt
rm -r logs/deltas
rm -r logs/cpp_deltas

echo "[DONE] Cleanup completed successfully."
echo ""
echo "Database data cleared."
echo "Sequences reset."
echo "Log files removed."