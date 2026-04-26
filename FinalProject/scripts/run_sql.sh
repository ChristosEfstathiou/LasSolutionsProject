#!/bin/bash
#Helper script for direct SQL execution, but the flow is fully menu-driven now.

source scripts/load_config.sh

if [ -z "$1" ]; then
  echo "Usage: ./scripts/run_sql.sh sql/file.sql"
  exit 1
fi

sqlplus ${DB_USER}/${DB_PASS}@//${DB_HOST}:${DB_PORT}/${DB_SERVICE} @"$1"