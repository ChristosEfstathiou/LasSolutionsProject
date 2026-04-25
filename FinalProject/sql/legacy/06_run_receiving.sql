PROMPT === PROCESSING RECEIPT 1 ===
EXEC process_receipt(1);

PROMPT === PROCESSING RECEIPT 2 ===
EXEC process_receipt(2);

PROMPT === PROCESSING RECEIPT 3 ===
EXEC process_receipt(3);

PROMPT === FINAL INVENTORY ===
SELECT
    p.product_name,
    l.location_code,
    l.is_refrigerated,
    i.quantity
FROM inventory i
JOIN products p ON p.product_id = i.product_id
JOIN locations l ON l.location_id = i.location_id
ORDER BY p.product_name, l.location_code;

PROMPT === RECEIPT STATUS ===
SELECT receipt_id, supplier_name, status
FROM receipts
ORDER BY receipt_id;

PROMPT === EVENT LOG ===
SELECT event_id, event_type, reference_type, reference_id, message
FROM event_log
ORDER BY event_id;