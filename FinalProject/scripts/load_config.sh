#!/bin/bash

CONFIG_FILE="config/receiving.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERROR] Config file not found: $CONFIG_FILE"
    exit 1
fi

set -a
source "$CONFIG_FILE"
set +a

echo "[INFO] Configuration loaded from $CONFIG_FILE"