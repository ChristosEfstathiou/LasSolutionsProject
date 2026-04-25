-- outbound queries - αναφορές για παραγγελίες και αποθέματα


-- 1. συνολικό απόθεμα ανά προϊόν
SELECT
    p.product_id,
    p.product_name,
    p.unit_of_measure,
    p.requires_refrigeration,
    NVL(SUM(i.quantity), 0) AS total_stock
FROM products p
LEFT JOIN inventory i ON p.product_id = i.product_id
GROUP BY p.product_id, p.product_name, p.unit_of_measure, p.requires_refrigeration
ORDER BY p.product_name;


-- 2. απόθεμα ανά προϊόν και αποθήκη
SELECT
    p.product_name,
    l.location_code,
    l.zone,
    i.quantity
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN locations l ON i.location_id = l.location_id
ORDER BY p.product_name, l.location_code;


-- 3. προϊόντα με χαμηλό απόθεμα (κάτω από 10)
SELECT
    p.product_id,
    p.product_name,
    p.unit_of_measure,
    NVL(SUM(i.quantity), 0) AS total_stock,
    10 AS low_stock_limit,
    CASE
        WHEN NVL(SUM(i.quantity), 0) = 0 THEN 'OUT OF STOCK'
        WHEN NVL(SUM(i.quantity), 0) < 10 THEN 'LOW STOCK'
        ELSE 'OK'
    END AS stock_status
FROM products p
LEFT JOIN inventory i ON p.product_id = i.product_id
GROUP BY p.product_id, p.product_name, p.unit_of_measure
HAVING NVL(SUM(i.quantity), 0) < 10
ORDER BY total_stock ASC;


-- 4. παραγγελίες που απέτυχαν
SELECT
    o.order_id,
    o.customer_name,
    o.order_date,
    o.status,
    e.message AS failure_reason
FROM customer_orders o
LEFT JOIN event_log e
    ON e.reference_id = o.order_id
    AND e.reference_type = 'ORDER'
    AND e.event_type = 'ORDER'
WHERE o.status = 'FAILED'
ORDER BY o.order_date DESC;


-- 5. ολοκληρωμένες παραγγελίες με λεπτομέρειες
SELECT
    o.order_id,
    o.customer_name,
    o.order_date,
    p.product_name,
    ol.quantity,
    p.unit_of_measure
FROM customer_orders o
JOIN order_lines ol ON o.order_id = ol.order_id
JOIN products p ON ol.product_id = p.product_id
WHERE o.status = 'COMPLETED'
ORDER BY o.order_id, p.product_name;

EXIT;
