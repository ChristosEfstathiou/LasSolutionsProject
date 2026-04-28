#!/bin/bash

export PATH=$PATH:/mnt/c/app/aldob/product/21c/dbhomeXE/bin

echo "=== RUN ORDER PROCESSING ==="

DB_USER="${ORA_USER:-HR}"
DB_PASS="${ORA_PASS:?ORA_PASS not set}"
DB_CONN="${ORA_CONN:-localhost/XEPDB1}"

ORDER_ID="${1:-1}"

sqlplus.exe -s /nolog <<EOF || { echo "ERROR: Order processing failed"; exit 1; }
CONNECT ${DB_USER}/${DB_PASS}@${DB_CONN}
WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
SET SERVEROUTPUT ON;

BEGIN
    process_order(${ORDER_ID});
END;
/

EXIT;
EOF

echo "=== ORDER ${ORDER_ID} COMPLETED ==="
