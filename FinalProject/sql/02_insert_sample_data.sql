-- PRODUCTS
INSERT INTO products VALUES (seq_products.NEXTVAL, 'Milk', 'Y', 'PCS');
INSERT INTO products VALUES (seq_products.NEXTVAL, 'Yogurt', 'Y', 'PCS');
INSERT INTO products VALUES (seq_products.NEXTVAL, 'Cheese', 'Y', 'PCS');
INSERT INTO products VALUES (seq_products.NEXTVAL, 'Rice', 'N', 'PCS');
INSERT INTO products VALUES (seq_products.NEXTVAL, 'Pasta', 'N', 'PCS');
INSERT INTO products VALUES (seq_products.NEXTVAL, 'Cereal', 'N', 'PCS');

-- LOCATIONS
INSERT INTO locations VALUES (seq_locations.NEXTVAL, 'FR-A1', 'COLD_ZONE_A', 'Y', 100, 0);
INSERT INTO locations VALUES (seq_locations.NEXTVAL, 'FR-A2', 'COLD_ZONE_A', 'Y', 100, 0);
INSERT INTO locations VALUES (seq_locations.NEXTVAL, 'FR-B1', 'COLD_ZONE_B', 'Y', 80, 0);

INSERT INTO locations VALUES (seq_locations.NEXTVAL, 'DR-A1', 'DRY_ZONE_A', 'N', 150, 0);
INSERT INTO locations VALUES (seq_locations.NEXTVAL, 'DR-A2', 'DRY_ZONE_A', 'N', 150, 0);
INSERT INTO locations VALUES (seq_locations.NEXTVAL, 'DR-B1', 'DRY_ZONE_B', 'N', 120, 0);

-- INITIAL INVENTORY

INSERT INTO inventory VALUES (seq_inventory.NEXTVAL, 1, 1, 30); 

UPDATE locations 
SET used_capacity = (SELECT used_capacity from locations WHERE location_id = 1) + 30
WHERE location_id = 1;

INSERT INTO inventory VALUES (seq_inventory.NEXTVAL, 3, 2, 20); 

UPDATE locations 
SET used_capacity = (SELECT used_capacity from locations WHERE location_id = 2) + 20 
WHERE location_id = 2;

INSERT INTO inventory VALUES (seq_inventory.NEXTVAL, 4, 4, 50); 

UPDATE locations 
SET used_capacity = (SELECT used_capacity from locations WHERE location_id = 4) + 50
WHERE location_id = 4;

INSERT INTO inventory VALUES (seq_inventory.NEXTVAL, 5, 5, 40); 

UPDATE locations 
SET used_capacity = (SELECT used_capacity from locations WHERE location_id = 5) + 40 
WHERE location_id = 5;

COMMIT;

EXIT;