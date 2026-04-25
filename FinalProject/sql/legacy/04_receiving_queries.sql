PROMPT === PRODUCTS ===
SELECT * FROM products ORDER BY product_id;

PROMPT === LOCATIONS ===
SELECT
    location_id,
    location_code,
    zone,
    is_refrigerated,
    capacity,
    used_capacity,
    capacity - used_capacity AS free_capacity
FROM locations
ORDER BY location_id;

PROMPT === INVENTORY ===
SELECT
    p.product_name,
    l.location_code,
    l.is_refrigerated,
    i.quantity
FROM inventory i
JOIN products p ON p.product_id = i.product_id
JOIN locations l ON l.location_id = i.location_id
ORDER BY p.product_name, l.location_code;

PROMPT === RECEIPTS ===
SELECT * FROM receipts ORDER BY receipt_id;

PROMPT === RECEIPT LINES ===
SELECT
    r.receipt_id,
    p.product_name,
    rl.quantity,
    r.status
FROM receipts r
JOIN receipt_lines rl ON rl.receipt_id = r.receipt_id
JOIN products p ON p.product_id = rl.product_id
ORDER BY r.receipt_id;

PROMPT === EVENT LOG ===
SELECT
    event_id,
    event_time,
    event_type,
    reference_type,
    reference_id,
    message
FROM event_log
ORDER BY event_id;