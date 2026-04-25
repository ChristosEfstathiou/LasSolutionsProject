#!/bin/bash

export PATH=$PATH:/mnt/c/app/aldob/product/21c/dbhomeXE/bin

echo "=== EVENT LOG ==="

# μεταβλητές σύνδεσης
DB_USER="${ORA_USER:-HR}"
DB_PASS="${ORA_PASS:?ORA_PASS not set}"
DB_CONN="${ORA_CONN:-localhost/XEPDB1}"

# παράμετρος για φιλτράρισμα - π.χ. bash show_logs.sh ERROR
FILTER="${1:-}"

sqlplus.exe -s /nolog <<SQLEOF
CONNECT ${DB_USER}/${DB_PASS}@${DB_CONN}
SET LINESIZE 150
SET PAGESIZE 100

$(if [ -n "$FILTER" ]; then
echo "-- φιλτράρισμα κατά: $FILTER"
echo "SELECT event_id, TO_CHAR(event_time,'DD-MON-YY HH24:MI:SS') AS event_time, event_type, reference_type, reference_id, message"
echo "FROM event_log"
echo "WHERE UPPER(event_type) = UPPER('$FILTER') OR UPPER(message) LIKE UPPER('%$FILTER%')"
echo "ORDER BY event_time DESC;"
else
echo "-- όλα τα logs"
echo "SELECT event_id, TO_CHAR(event_time,'DD-MON-YY HH24:MI:SS') AS event_time, event_type, reference_type, reference_id, message"
echo "FROM event_log"
echo "ORDER BY event_time DESC;"
fi)

EXIT;
SQLEOF

echo "=== ΤΕΛΟΣ ==="
