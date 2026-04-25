# FlowCore – Inbound Receiving Automation Platform

## Overview

FlowCore is a warehouse automation project focused on inbound receiving and putaway operations.

The solution simulates a realistic commissioning environment by combining:

- Bash automation scripts
- Oracle Database schema and transactions
- PL/SQL warehouse business logic
- C++ allocation engine
- CSV-driven automated testing
- Delta logs and validation reports
- Configurable receiving rules
- Master data maintenance processes

The project was designed to demonstrate practical software commissioning skills for warehouse and logistics systems.

---

# Core Features

## Inbound Receiving Flow

Processes incoming stock by:

- validating input data
- selecting the best storage location
- creating receipts
- creating receipt lines
- updating inventory
- updating location capacity
- writing audit events

---

## Dynamic C++ Allocation Engine

The C++ module:

- reads warehouse state exported from Oracle
- applies storage rules
- selects best-fit locations
- supports same-product preference logic
- updates working CSV state during simulation

---

## Oracle as System of Record

Oracle stores and controls:

- products
- locations
- receipts
- receipt lines
- inventory
- event logs

All final transactions are validated and persisted in the database.

---

## CSV Test Automation

Inbound scenarios are executed from CSV files.

Supports:

- positive flows
- negative flows
- capacity overflow
- refrigeration mismatch
- invalid products
- continuation scenarios
- post-master-data-update scenarios

---

## Detailed Delta Logging

Each test generates detailed logs containing:

- input parameters
- config values
- C++ output
- DB output
- inventory snapshot
- capacity snapshot
- new receipts
- new events

---

## Configurable Rules

Configuration file:

```text
config/receiving.conf

### Recommended Demo Execution Flow

Run the main control menu:

```bash
./scripts/master_menu.sh

From the menu, follow this sequence:

1. Choose Option 1 – Full Rebuild

This runs:

./scripts/full_rebuild.sh

It recreates the project environment from scratch by:

dropping previous schema objects
recreating tables
recreating sequences
recreating indexes
recreating PL/SQL procedures and functions
loading the base products master data
loading the base locations master data

Use this when you want a completely clean environment.

2. Choose Option 2 – Run inbound flow receiving each csv file is treated as a single receipt test and each line is a receipt line

This runs:

./scripts/run_inbound_flow.sh

The menu will display all available inbound CSV test files.

You may:

choose one of the listed files
or press Enter to run the default file

Default file:

test_data/cpp_multiple_product_after_master_update.csv

The inbound flow performs:

configuration validation
Oracle connection validation
C++ allocator compilation
warehouse state export from Oracle
CSV test execution line by line
Oracle receiving transaction processing
rollback protection if DB rejects transaction
delta log creation per test case
summary report creation
final validation export

3. Choose Option 8 – Update Master Data (the second test will give correct results only if you have run the default file in first test)

After completing the first inbound run, choose:

8

This runs:

./scripts/update_master_data.sh

It reads:

data/updated_products.csv
data/updated_locations.csv

This allows the client to operationally update the system without rebuild.

Supported changes:

add new products
add new locations
increase capacity of existing locations

Protected rules:

existing products remain unchanged
location refrigeration type cannot change
used capacity is preserved
current inventory is not lost

4. Choose Option 2 Again – Run Post-Update Test

Run inbound flow again using Option 2.

This time select:

test_data/cpp_multiple_product_after_master_update.csv

This demonstrates that the system correctly uses:

newly added products
newly added locations
expanded location capacities

5. Choose Option 3 – Export Final Reports

This runs the reporting/export process.

Generated outputs show:

receipts created
receipt lines created
inventory by location
location free capacity
event logs
validation results

This is useful for final demonstration and verification.

6. Optional Option 4 – Cleanup Environment (if you haven't updated the master_data, meaning you have skipped steps 3 and 4 of this guide you retest without rebuilding)

If you ran inbound tests but do not want to continue with master data updates, choose:

4

This runs:

./scripts/cleanup_environment.sh

It removes:

generated logs
temporary CSV working files
previous output artifacts

Use it before starting another clean test cycle.

Recommended Full Demo Sequence
1 → Full Rebuild
2 → Run Inbound Flow (default CSV)
8 → Update Master Data
2 → Run Inbound Flow (cpp_multiple_product_after_master_update.csv)
3 → Export Reports
needs full rebuild to rerun a test. 

Or 

1 → Full Rebuild
2 → Run Inbound Flow (any CSV except for cpp_multiple_product_after_master_update.csv)
3 → Export Reports
4 → Cleanup Environment
repeat


Option 7 from Master Menu
## Legacy SQL-Only Test Option

The SQL-only test flow exists to validate the Oracle PL/SQL receiving logic independently from the C++ allocator.

Purpose:
- isolate database logic testing
- verify stored procedures directly
- confirm constraints and transaction handling
- support troubleshooting when allocator logic is not under review

Why it is not the primary method:
- it does not test the full integrated flow
- it bypasses the C++ allocation engine
- it does not simulate external decision logic
- it is less representative of the final production process

Current recommendation:
Use the integrated inbound flow (`run_inbound_flow.sh`) as the main demonstration path, and keep the SQL-only option as a technical validation / diagnostic tool.