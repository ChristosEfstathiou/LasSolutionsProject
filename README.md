# FlowCore Warehouse Project — Outbound Operations

A warehouse commissioning simulation built for the Junior Software Commissioning Engineer Bootcamp.

## Overview

This repository contains the **outbound operations** module of the FlowCore warehouse simulation. It handles customer order processing, stock validation, inventory deduction, and dispatch flow.

The project simulates how a food warehouse processes customer orders — from receiving the order to completing or failing it based on stock availability.

## Project Structure

```
warehouse-project/
├── sql/
│   ├── 01_create_schema.sql        — database tables and sequences
│   ├── 02_sample_orders.sql        — sample products, locations, inventory
│   ├── 03_plsql_orders.sql         — process_order procedure
│   ├── 04_reports.sql              — basic reports
│   ├── 05_outbound_queries.sql     — outbound SQL queries
│   └── 06_plsql_function_and_tests.sql  — has_sufficient_stock + 8 test cases
├── scripts/
│   ├── run_all.bat                 — full system run (Windows CMD)
│   ├── run_orders.sh               — run a single order (Linux/WSL)
│   ├── order_report.sh             — show orders and inventory report
│   ├── validate_orders.sh          — validate environment before running
│   ├── show_logs.sh                — show event log from database
│   └── outbound.conf               — configuration parameters
├── cpp/
│   └── stock_allocation.cpp        — stock allocation helper (C++)
└── .gitignore
```

## Order Status Flow

```
RECEIVED → UNDER_PROCEDURE → COMPLETED (stock deducted)
                           → FAILED    (insufficient stock)
```

## How to Run

### Windows (CMD)

```cmd
D:
cd D:\warehouse_project\scripts
set ORA_USER=HR
set ORA_PASS=your_password
set ORA_CONN=localhost/XEPDB1
run_all.bat
```

### Linux / WSL

```bash
cd /mnt/d/warehouse_project/scripts
export ORA_USER=HR
export ORA_PASS=your_password
export ORA_CONN=localhost/XEPDB1
bash validate_orders.sh
bash order_report.sh
```

### C++ (MSYS2)

```bash
cd /d/warehouse_project/cpp
g++ -o stock_allocation stock_allocation.cpp
./stock_allocation
```

## Test Results

| # | Test | Expected | Result |
|---|------|----------|--------|
| 1 | Sufficient stock — order 1 | COMPLETED | ✅ PASS |
| 2 | Sufficient stock — order 2 | COMPLETED | ✅ PASS |
| 3 | Stock reduced after COMPLETED | Milk=40 Yogurt=25 Rice=60 Pasta=45 | ✅ PASS |
| 4 | Insufficient stock | FAILED | ✅ PASS |
| 5 | One product missing | FAILED | ✅ PASS |
| 6 | Event log entries written | >= 1 entry | ✅ PASS |
| 7 | Low stock report | 1 product below limit | ✅ PASS |
| 8a | has_sufficient_stock — enough | Y | ✅ PASS |
| 8b | has_sufficient_stock — not enough | N | ✅ PASS |

**Total: 9/9 PASS**

## Tech Stack

- Oracle Database 21c XE
- SQL / PL/SQL
- Bash / WSL2
- Windows CMD
- C++ (g++ / MSYS2)
- Git / GitHub

## Author

Bardi Alnto — Outbound Operations  
Junior Software Commissioning Engineer Bootcamp — April 2026

## Run Everything at Once

To run the complete demo in one command (CMD, WSL and C++ together):

```cmd
set ORA_USER=HR
set ORA_PASS=hr
set ORA_CONN=localhost/XEPDB1
run_everything.bat
```

This runs the full pipeline, WSL validation and reports, and the C++ stock allocator automatically.
