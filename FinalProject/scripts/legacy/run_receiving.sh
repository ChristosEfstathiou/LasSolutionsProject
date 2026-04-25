#!/bin/bash
# Legacy wrapper script kept for reference.
# Replaced by master_menu.sh and dedicated inbound flow scripts.
echo "======================================"
echo " FlowCore Receiving / Putaway Runner"
echo "======================================"

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

echo "[INFO] Running receiving PL/SQL logic..."
$SQLPLUS_CMD @sql/06_run_receiving.sql

echo "[INFO] Receiving flow completed."