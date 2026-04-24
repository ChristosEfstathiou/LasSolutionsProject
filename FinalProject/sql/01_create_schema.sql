-- =========================================
-- 01_create_schema.sql
-- Food Warehouse Project Schema
-- =========================================

-- =========================================
-- SEQUENCES
-- =========================================

CREATE SEQUENCE seq_products START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_locations START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_inventory START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_receipts START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_receipt_lines START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_customer_orders START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_order_lines START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_event_log START WITH 1 INCREMENT BY 1;

-- =========================================
-- PRODUCTS
-- =========================================

CREATE TABLE products (
    product_id NUMBER PRIMARY KEY,
    product_name VARCHAR2(100) NOT NULL,
    requires_refrigeration CHAR(1) NOT NULL,
    unit_of_measure VARCHAR2(20) DEFAULT 'PCS' NOT NULL,
    CONSTRAINT chk_products_refrigeration
        CHECK (requires_refrigeration IN ('Y', 'N'))
);

-- =========================================
-- LOCATIONS
-- =========================================

CREATE TABLE locations (
    location_id NUMBER PRIMARY KEY,
    location_code VARCHAR2(30) NOT NULL UNIQUE,
    zone VARCHAR2(30) NOT NULL,
    is_refrigerated CHAR(1) NOT NULL,
    capacity NUMBER NOT NULL,
    used_capacity NUMBER DEFAULT 0 NOT NULL,
    CONSTRAINT chk_locations_refrigeration
        CHECK (is_refrigerated IN ('Y', 'N')),
    CONSTRAINT chk_locations_capacity
        CHECK (capacity >= 0),
    CONSTRAINT chk_locations_used_capacity
        CHECK (used_capacity >= 0 AND used_capacity <= capacity)
);

-- =========================================
-- INVENTORY
-- =========================================

CREATE TABLE inventory (
    inventory_id NUMBER PRIMARY KEY,
    product_id NUMBER NOT NULL,
    location_id NUMBER NOT NULL,
    quantity NUMBER NOT NULL,
    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_inventory_location
        FOREIGN KEY (location_id) REFERENCES locations(location_id),
    CONSTRAINT chk_inventory_quantity
        CHECK (quantity >= 0),
    CONSTRAINT uq_inventory_product_location
        UNIQUE (product_id, location_id)
);

-- =========================================
-- RECEIPTS
-- =========================================

CREATE TABLE receipts (
    receipt_id NUMBER PRIMARY KEY,
    supplier_name VARCHAR2(100) NOT NULL,
    receipt_date DATE DEFAULT SYSDATE NOT NULL,
    status VARCHAR2(20) DEFAULT 'RECEIVED' NOT NULL,
    CONSTRAINT chk_receipts_status
        CHECK (status IN ('RECEIVED', 'PROCESSED', 'FAILED', 'NEW', 'PENDING'))
);

-- =========================================
-- RECEIPT_LINES
-- =========================================

CREATE TABLE receipt_lines (
    receipt_line_id NUMBER PRIMARY KEY,
    receipt_id NUMBER NOT NULL,
    product_id NUMBER NOT NULL,
    quantity NUMBER NOT NULL,
    CONSTRAINT fk_receipt_lines_receipt
        FOREIGN KEY (receipt_id) REFERENCES receipts(receipt_id),
    CONSTRAINT fk_receipt_lines_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT chk_receipt_lines_quantity
        CHECK (quantity > 0)
);

-- =========================================
-- CUSTOMER_ORDERS
-- =========================================

CREATE TABLE customer_orders (
    order_id NUMBER PRIMARY KEY,
    customer_name VARCHAR2(100) NOT NULL,
    order_date DATE DEFAULT SYSDATE NOT NULL,
    status VARCHAR2(30) DEFAULT 'RECEIVED' NOT NULL,
    CONSTRAINT chk_customer_orders_status
        CHECK (status IN ('RECEIVED', 'UNDER_PROCEDURE', 'COMPLETED', 'FAILED'))
);

-- =========================================
-- ORDER_LINES
-- =========================================

CREATE TABLE order_lines (
    order_line_id NUMBER PRIMARY KEY,
    order_id NUMBER NOT NULL,
    product_id NUMBER NOT NULL,
    quantity NUMBER NOT NULL,
    CONSTRAINT fk_order_lines_order
        FOREIGN KEY (order_id) REFERENCES customer_orders(order_id),
    CONSTRAINT fk_order_lines_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT chk_order_lines_quantity
        CHECK (quantity > 0)
);

-- =========================================
-- EVENT_LOG
-- =========================================

CREATE TABLE event_log (
    event_id NUMBER PRIMARY KEY,
    event_time DATE DEFAULT SYSDATE NOT NULL,
    event_type VARCHAR2(50) NOT NULL,
    reference_type VARCHAR2(30),
    reference_id NUMBER,
    message VARCHAR2(400)
);

-- =========================================
-- INDEXES
-- =========================================

CREATE INDEX idx_inventory_product
ON inventory(product_id);

CREATE INDEX idx_inventory_location
ON inventory(location_id);

CREATE INDEX idx_receipt_lines_receipt
ON receipt_lines(receipt_id);

CREATE INDEX idx_order_lines_order
ON order_lines(order_id);

CREATE INDEX idx_event_log_reference
ON event_log(reference_type, reference_id);

PROMPT Schema creation completed.

EXIT;