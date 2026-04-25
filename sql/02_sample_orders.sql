WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

-- καθαρισμός παλιών δεδομένων για fresh start
DELETE FROM inventory;
DELETE FROM order_lines;
DELETE FROM customer_orders;
DELETE FROM receipt_lines;
DELETE FROM receipts;
DELETE FROM locations;
DELETE FROM products;
DELETE FROM event_log;

-- προϊόντα - ίδια με το inbound module
INSERT INTO products VALUES (seq_products.NEXTVAL, 'Milk',   'Y', 'PCS');
INSERT INTO products VALUES (seq_products.NEXTVAL, 'Yogurt', 'Y', 'PCS');
INSERT INTO products VALUES (seq_products.NEXTVAL, 'Cheese', 'Y', 'PCS');
INSERT INTO products VALUES (seq_products.NEXTVAL, 'Rice',   'N', 'PCS');
INSERT INTO products VALUES (seq_products.NEXTVAL, 'Pasta',  'N', 'PCS');
INSERT INTO products VALUES (seq_products.NEXTVAL, 'Cereal', 'N', 'PCS');

-- αποθήκες - ίδιες με το inbound module
INSERT INTO locations VALUES (seq_locations.NEXTVAL, 'FR-A1', 'COLD_ZONE_A', 'Y', 100, 0);
INSERT INTO locations VALUES (seq_locations.NEXTVAL, 'FR-A2', 'COLD_ZONE_A', 'Y', 100, 0);
INSERT INTO locations VALUES (seq_locations.NEXTVAL, 'FR-B1', 'COLD_ZONE_B', 'Y', 80,  0);
INSERT INTO locations VALUES (seq_locations.NEXTVAL, 'DR-A1', 'DRY_ZONE_A',  'N', 150, 0);
INSERT INTO locations VALUES (seq_locations.NEXTVAL, 'DR-A2', 'DRY_ZONE_A',  'N', 150, 0);
INSERT INTO locations VALUES (seq_locations.NEXTVAL, 'DR-B1', 'DRY_ZONE_B',  'N', 120, 0);

-- αρχικό απόθεμα
INSERT INTO inventory VALUES (seq_inventory.NEXTVAL, 1, 1, 50);
INSERT INTO inventory VALUES (seq_inventory.NEXTVAL, 2, 1, 30);
INSERT INTO inventory VALUES (seq_inventory.NEXTVAL, 3, 2, 40);
INSERT INTO inventory VALUES (seq_inventory.NEXTVAL, 4, 4, 80);
INSERT INTO inventory VALUES (seq_inventory.NEXTVAL, 5, 5, 60);
INSERT INTO inventory VALUES (seq_inventory.NEXTVAL, 6, 6, 70);

-- δοκιμαστική παραγγελία 1 - ψυχρά προϊόντα
INSERT INTO customer_orders VALUES (seq_customer_orders.NEXTVAL, 'Cold Customer', SYSDATE, 'RECEIVED');
INSERT INTO order_lines VALUES (seq_order_lines.NEXTVAL, 1, 1, 10);
INSERT INTO order_lines VALUES (seq_order_lines.NEXTVAL, 1, 2, 5);

-- δοκιμαστική παραγγελία 2 - ξηρά προϊόντα
INSERT INTO customer_orders VALUES (seq_customer_orders.NEXTVAL, 'Dry Customer', SYSDATE, 'RECEIVED');
INSERT INTO order_lines VALUES (seq_order_lines.NEXTVAL, 2, 4, 20);
INSERT INTO order_lines VALUES (seq_order_lines.NEXTVAL, 2, 5, 15);

-- log για να φαίνεται ότι φορτώθηκαν τα δεδομένα
INSERT INTO event_log VALUES (seq_event_log.NEXTVAL, SYSDATE, 'INIT', 'SYSTEM', NULL, 'Reloaded sample data');

COMMIT;

EXIT;
