# FlowCore – Inbound Module Known Limitations

## Overview
This document lists the current limitations of the FlowCore inbound receiving module.  
The solution is fully functional for the project scope, but some advanced warehouse features are intentionally simplified or reserved for future enhancement.

---

# 1. No Split Storage (Current Rule)

A single receipt line must fit into one location.

Example:

- Receiving 120 units
- Free capacity:
  - Location A = 70
  - Location B = 80

Current result:

- Rejected

Even though total free space is enough, the system does not split stock across multiple locations.

Future enhancement:
- Multi-location putaway allocation

---

# 2. Console / Script Driven Interface

The project currently uses:

- Bash scripts
- SQL*Plus
- CSV input files
- Text reports

There is no web or desktop GUI.

Future enhancement:
- Web dashboard
- Operator screens
- Real-time monitoring UI

---

# 3. C++ Allocator Is a Decision Engine

The C++ module is responsible for:

- Reading warehouse state from CSV
- Applying allocation rules
- Returning best-fit location decisions
- Simulating state changes

Oracle remains the system of record for:

- Receipts
- Inventory
- Event logs
- Final transaction persistence

---

# 4. Sequential Test Execution

CSV test files run line-by-line in sequence.

This is ideal for testing continuation scenarios, but does not simulate:

- Concurrent users
- Parallel receiving activity
- Locking/contention scenarios

Future enhancement:
- Multi-session load testing

---

# 5. Master Data Assumptions

Products and locations are controlled through CSV update scripts.

Current rules:

- Existing products are not modified
- Existing location type cannot change
- Existing location capacity can only increase
- New products and locations can be added

Future enhancement:
- Full master data maintenance UI

---

# 6. Basic Validation Scope

The current solution validates:

- Invalid product IDs
- Quantity <= 0
- Refrigeration mismatch between CSV and product master data
- Capacity overflow
- Missing storage space

Future enhancement:

- Supplier validation
- Duplicate receipt detection
- Batch / lot control
- Expiry date validation
- Barcode scanning integration

---

# 7. Logging Output Format

Reports are generated as:

- TXT files
- CSV files
- SQL query outputs

Future enhancement:

- PDF reports
- Dashboards
- KPI analytics
- Email alerts

---

# 8. Warehouse Strategy Scope


Current allocation strategy supports:

- Refrigerated vs dry compatibility
- Best-fit capacity selection
- Optional same-product preference

Future enhancement:

### FIFO (First In, First Out)

The oldest stock received is used first.

Example:  
If two pallets of milk exist, and one was received last week while the other arrived today, the system will pick last week's pallet first.

---

### FEFO (First Expired, First Out)

The stock with the earliest expiration date is used first, even if it was received later.

Example:  
Yogurt expiring tomorrow should be shipped before yogurt expiring next week.

---

### Zone Priority Logic

Some warehouse areas are preferred over others.

Example:

- Fast-moving items near dispatch area
- Reserve stock in distant racks
- Frozen items in premium cold zone first

The system would choose locations based not only on space, but also on business priority.

---

### Travel Distance Optimization

The system chooses storage locations that reduce forklift or worker travel time.

Example:  
If two locations both fit the product, the closer one to receiving docks may be selected.

---

### ABC Slotting Strategy

Products are stored based on how frequently they move.

Typical categories:

- A Items = high demand / picked very often
- B Items = medium demand
- C Items = low demand / rarely moved

Example:

- Best-selling products stored close to packing area
- Slow-moving products stored in higher or distant shelves

---

### Product Incompatibility Rules

Some products should not be stored near each other.

Examples:

- Food separated from chemicals
- Fragile items separated from heavy items
- Strong-smelling products separated from absorbent goods
- Frozen and ambient products separated

The system would block invalid storage combinations.

---

# 9. Security Model

This academic project uses local configuration files for database credentials.

Future enhancement:

- Secret vault integration
- Role-based access control
- User authentication
- Audit permissions

---

# 10. Rejected Lines Are Logged, Not Stored as Receipt Lines

In the current design, CSV rows that fail validation do **not** create records in the `receipt_lines` table.

Examples:

- Invalid product ID
- Wrong refrigeration flag
- Zero or negative quantity
- No available storage capacity

Only validated and operationally accepted rows become `receipt_lines`.

### Why This Design Was Chosen

The project separates business transactions from exceptions:

Operational data  -> receipts / receipt_lines / inventory
Exceptions        -> event_log

Future Enhancement:

A future version could allow rejected rows to be inserted into receipt_lines with a processing status column, enabling:

Partial receipt acceptance
Exception handling workflows
User correction and reprocessing
Richer operational reporting

# Final Note

These limitations do not prevent successful inbound receiving execution for the project scope.  
They identify realistic next steps for evolving FlowCore into a production-grade warehouse solution.