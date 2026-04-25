# FlowCore – Inbound Receiving Flow

## Overview

This document describes the complete inbound receiving simulation implemented for the FlowCore warehouse commissioning project. It covers the integrated use of Linux/Bash, Oracle SQL & PL/SQL, C++, configuration files, automated testing, reporting, and validation.

The inbound module simulates how a food warehouse receives products, selects suitable storage locations, updates inventory, and validates technical behavior through repeatable automated tests.

---

# 1. Business Scenario

A food warehouse receives incoming goods from suppliers and stores them in internal warehouse locations.

Products are divided into two categories:

* Refrigerated products
* Dry products

The system must:

1. Accept receipts
2. Decide where products should be stored
3. Update warehouse capacity usage
4. Update inventory balances
5. Record receipt status
6. Produce logs and validation reports
7. Support automated testing

---

# 2. Functional Scope

## Included

* Product master data
* Warehouse locations with capacities
* Receipt processing
* Putaway logic
* Inventory tracking
* Oracle database updates
* C++ allocation engine
* CSV-driven automated tests
* Delta logs after each test
* Bash orchestration scripts
* Rebuild / cleanup utilities

## Excluded

* Barcode scanners
* Real ERP integration
* Multi-user concurrency
* Web UI
* Advanced product categories
* Route optimization

---

# 3. Technology Stack

## Linux / WSL2

Used for all command-line execution and automation.

## Docker Desktop

Hosts Oracle Free database container.

## VS Code

Used for development of SQL, Bash, C++, and documentation.

## Oracle SQL / PL/SQL

Used for transactional warehouse logic.

## Bash Scripts

Used for automation, reporting, orchestration, and test execution.

## C++

Used as an external decision engine for putaway allocation.

## Git

Used for source/version control.

---

# 4. Database Design

## Main Tables

## PRODUCTS

Stores product master data.

* product_id
* product_name
* requires_refrigeration
* unit_of_measure

## LOCATIONS

Stores warehouse locations.

* location_id
* location_code
* zone
* is_refrigerated
* capacity
* used_capacity

## INVENTORY

Stores current stock by product/location.

* inventory_id
* product_id
* location_id
* quantity

## RECEIPTS

Stores inbound receipts.

* receipt_id
* supplier_name
* receipt_date
* status

Statuses:

* RECEIVED
* PROCESSED
* FAILED
* REJECTED

## RECEIPT_LINES

Stores products per receipt.

* receipt_line_id
* receipt_id
* product_id
* quantity

## EVENT_LOG

Stores operational events.

* event_id
* event_type
* reference_type
* reference_id
* message
* created_at

---

# 5. Core Receiving Logic

## Input

A supplier delivers products and quantities.

## Validation

The system validates:

* product exists
* quantity > 0
* suitable location exists
* capacity available

## Putaway Rule

Products must be stored in locations where:

* refrigeration matches product requirement
* enough free capacity exists

## Best-Fit Allocation Rule

The system chooses:

> the compatible location with the smallest free capacity that can still fit the incoming quantity.

This minimizes wasted space.

## Same Product Preference

If an existing location already contains the same product and can fit the quantity, it is preferred.

## Inventory Update

If successful:

* inventory increases
* location used_capacity increases
* receipt status = PROCESSED

If no location fits:

* receipt status = FAILED

If input is invalid:

* receipt status = REJECTED

---

# 6. PL/SQL Components

## find_putaway_location(product_id, quantity)

Returns the best location according to warehouse rules.

## process_receipt(receipt_id)

Processes receipt lines and updates:

* inventory
* locations
* receipts
* event_log

## process_receipt_from_cli.sql

Used by Bash automation to insert and process one receipt from command line inputs.

---

# 7. C++ Allocation Engine

## Purpose

Acts as an external lightweight decision engine.

It reads warehouse state from CSV and decides if storage is possible.

## Inputs

* refrigeration flag (Y/N)
* quantity
* CSV location file
* update state flag

## Outputs

* selected location
* reason for selection
* exit code

## Exit Codes

* 0 = success
* 1 = invalid input
* 2 = no suitable location found

## Dynamic State Mode

During test execution, the C++ allocator updates a working CSV file after successful allocations.

This means later tests use the updated warehouse state.

## Rollback Protection

If C++ succeeds but Oracle rejects the transaction, the CSV state is rolled back automatically to keep both systems synchronized.

---

# 8. Automation Scripts

## run_inbound_flow_multiple_products.sh

Main end-to-end simulation.

### Steps

1. Check DB connection
2. Compile C++ module
3. Export DB location state to CSV
4. Run C++ test cases
5. Update Oracle DB for successful allocations
6. Rollback CSV if DB rejects transaction
7. Create detailed delta logs
8. Export final validation report

## run_csv_tests.sh

Runs SQL/PLSQL receipt tests using CSV input files, legacy.

## full_rebuild.sh

Drops and recreates schema from scratch.

## cleanup_environment.sh

Deletes simulation data and logs.

## master_menu.sh

Interactive control panel for running all project functions.

---

# 9. Test Frameworks

## SQL / PL/SQL CSV Tests

CSV files drive receipt processing tests.

Example checks:

* valid receipt processed
* no capacity available
* invalid product id
* zero quantity
* negative quantity
* continuation tests after previous runs

## C++ + DB Integration Tests

CSV files test:

* allocator decisions
* Oracle updates
* rollback logic
* DB constraint rejection

---

# 10. Delta Logs

A delta log is created for every test case.

Each file includes:

* test input
* expected vs actual results
* C++ output
* DB output
* warehouse state after test

This provides full traceability.

---

# 11. Example Validation Scenario

## Invalid Product Test

Input:

* product_id = 999
* quantity = 10

Result:

* C++ finds a location
* Oracle rejects foreign key
* CSV state rolls back
* Final result = PASS (expected rejection)


