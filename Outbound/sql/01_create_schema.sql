-- διαγραφή πινάκων αν υπάρχουν ήδη
SET DEFINE OFF;
WHENEVER SQLERROR CONTINUE;

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE event_log CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE order_lines CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE customer_orders CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE receipt_lines CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE receipts CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE inventory CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE locations CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE products CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- διαγραφή sequences αν υπάρχουν
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_products'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_locations'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_inventory'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_receipts'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_receipt_lines'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_customer_orders'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_order_lines'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_event_log'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- sequences για auto increment
CREATE SEQUENCE seq_products START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_locations START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_inventory START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_receipts START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_receipt_lines START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_customer_orders START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_order_lines START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_event_log START WITH 1 INCREMENT BY 1;

-- πίνακας προϊόντων
CREATE TABLE products (
    product_id NUMBER PRIMARY KEY,
    product_name VARCHAR2(100) NOT NULL,
    requires_refrigeration CHAR(1) NOT NULL,
    unit_of_measure VARCHAR2(20) DEFAULT 'PCS',
    CONSTRAINT chk_products_refrigeration
        CHECK (requires_refrigeration IN ('Y', 'N'))
);

-- αποθήκες / θέσεις
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

-- παραλαβές από προμηθευτές
CREATE TABLE receipts (
    receipt_id NUMBER PRIMARY KEY,
    supplier_name VARCHAR2(100) NOT NULL,
    receipt_date DATE DEFAULT SYSDATE NOT NULL,
    status VARCHAR2(20) DEFAULT 'RECEIVED' NOT NULL,
    CONSTRAINT chk_receipts_status
        CHECK (status IN ('RECEIVED', 'PROCESSED', 'FAILED'))
);

-- παραγγελίες πελατών
CREATE TABLE customer_orders (
    order_id NUMBER PRIMARY KEY,
    customer_name VARCHAR2(100) NOT NULL,
    order_date DATE DEFAULT SYSDATE NOT NULL,
    status VARCHAR2(30) DEFAULT 'RECEIVED' NOT NULL,
    CONSTRAINT chk_customer_orders_status
        CHECK (status IN ('RECEIVED', 'UNDER_PROCEDURE', 'COMPLETED', 'FAILED'))
);

-- αποθέματα ανά προϊόν και θέση
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

-- γραμμές παραλαβής
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

-- γραμμές παραγγελίας
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

-- καταγραφή συμβάντων
CREATE TABLE event_log (
    event_id NUMBER PRIMARY KEY,
    event_time DATE DEFAULT SYSDATE NOT NULL,
    event_type VARCHAR2(50) NOT NULL,
    reference_type VARCHAR2(30),
    reference_id NUMBER,
    message VARCHAR2(400)
);

EXIT;
