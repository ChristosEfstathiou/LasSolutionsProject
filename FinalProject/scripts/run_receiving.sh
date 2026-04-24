#!/bin/bash

echo "======================================"
echo " FlowCore Receiving / Putaway Runner"
echo "======================================"

source scripts/load_config.sh

SQLPLUS_CMD="sqlplus -s ${DB_USER}/${DB_PASS}@//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"

echo "[INFO] Running receiving PL/SQL logic..."
$SQLPLUS_CMD @sql/06_run_receiving.sql

echo "[INFO] Receiving flow completed."