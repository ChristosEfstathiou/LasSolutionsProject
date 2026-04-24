SET PAGESIZE 100
SET LINESIZE 220
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
SET UNDERLINE =
SET TRIMSPOOL ON

DEFINE before_receipt_id = '&1'
DEFINE before_event_id = '&2'

PROMPT
PROMPT ============================================================
PROMPT CURRENT LOCATION CAPACITY AFTER THIS TEST
PROMPT ============================================================

SELECT
    location_code,
    zone,
    capacity,
    used_capacity,
    capacity - used_capacity AS free_capacity
FROM locations
ORDER BY location_id;

PROMPT ============================================================
PROMPT NEW RECEIPTS CREATED BY THIS TEST
PROMPT ============================================================

SELECT
    receipt_id,
    supplier_name,
    TO_CHAR(receipt_date, 'YYYY-MM-DD HH24:MI:SS') AS receipt_date,
    status
FROM receipts
WHERE receipt_id > &before_receipt_id
ORDER BY receipt_id;

PROMPT
PROMPT ============================================================
PROMPT NEW RECEIPT LINES CREATED BY THIS TEST
PROMPT ============================================================

SELECT
    rl.receipt_line_id,
    rl.receipt_id,
    p.product_name,
    rl.quantity
FROM receipt_lines rl
JOIN products p ON p.product_id = rl.product_id
WHERE rl.receipt_id > &before_receipt_id
ORDER BY rl.receipt_line_id;

PROMPT
PROMPT ============================================================
PROMPT NEW EVENTS CREATED BY THIS TEST
PROMPT ============================================================

SELECT
    event_id,
    event_type,
    reference_type,
    reference_id,
    message
FROM event_log
WHERE event_id > &before_event_id
ORDER BY event_id;

PROMPT
PROMPT ============================================================
PROMPT CURRENT INVENTORY SNAPSHOT AFTER THIS TEST
PROMPT ============================================================

SELECT
    p.product_name,
    l.location_code,
    CASE
        WHEN l.is_refrigerated = 'Y' THEN 'REFRIGERATED'
        ELSE 'DRY'
    END AS storage_type,
    i.quantity
FROM inventory i
JOIN products p ON p.product_id = i.product_id
JOIN locations l ON l.location_id = i.location_id
ORDER BY p.product_name, l.location_code;



EXIT;