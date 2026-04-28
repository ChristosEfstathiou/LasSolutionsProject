#!/bin/bash

export PATH=$PATH:/mnt/c/app/aldob/product/21c/dbhomeXE/bin

echo "=== ORDER REPORT ==="
echo "Run at: $(date)"

DB_USER="${ORA_USER:-HR}"
DB_PASS="${ORA_PASS:?ORA_PASS not set}"
DB_CONN="${ORA_CONN:-localhost/XEPDB1}"

sqlplus.exe -s ${DB_USER}/${DB_PASS}@${DB_CONN} <<EOF

SET LINESIZE 200
SET PAGESIZE 50

PROMPT === CUSTOMER ORDERS ===
SELECT * FROM customer_orders WHERE ROWNUM <= 1000;

PROMPT === ORDER LINES ===
SELECT * FROM order_lines WHERE ROWNUM <= 1000;

PROMPT === INVENTORY ===
SELECT * FROM inventory WHERE ROWNUM <= 1000;

PROMPT === EVENT LOG ===
SELECT * FROM event_log WHERE ROWNUM <= 1000 ORDER BY event_time;

EXIT;
EOF

echo "=== REPORT DONE ==="
