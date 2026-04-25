#!/bin/bash

echo "========================================="
echo " FlowCore Full Database Rebuild"
echo "========================================="

source scripts/load_config.sh

mkdir -p logs

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="logs/full_rebuild_${TIMESTAMP}.txt"

exec > >(tee -a "$LOG_FILE") 2>&1

SQLPLUS_CMD="sqlplus -L -s ${DB_USER}/${DB_PASS}@//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"

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
    echo "[ERROR] You can start it with: docker start oracle-db"
    exit 1
fi

echo ""
echo "[STEP 2] Dropping old schema objects..."
$SQLPLUS_CMD @sql/00_drop_schema.sql

if [ $? -ne 0 ]; then
    echo "[ERROR] Drop schema failed."
    exit 1
fi

echo ""
echo "[STEP 3] Creating schema..."
$SQLPLUS_CMD @sql/01_create_schema.sql

if [ $? -ne 0 ]; then
    echo "[ERROR] Schema creation failed."
    exit 1
fi

echo ""
echo "[STEP 4] Inserting sample data..."
./scripts/load_master_data.sh

if [ $? -ne 0 ]; then
    echo "[ERROR] Sample data insert failed."
    exit 1
fi

echo ""
echo "[STEP 5] Creating PL/SQL receiving logic..."
$SQLPLUS_CMD @sql/05_receiving_plsql.sql

if [ $? -ne 0 ]; then
    echo "[ERROR] PL/SQL deployment failed."
    exit 1
fi

echo ""
echo "[DONE] Full rebuild completed successfully."
echo "Finished at: $(date)"
echo "Log saved to: $LOG_FILE"