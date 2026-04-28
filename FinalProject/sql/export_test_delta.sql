SET PAGESIZE 100
SET LINESIZE 280
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
SET UNDERLINE =
SET TRIMSPOOL ON
SET WRAP OFF
SET TAB OFF

COLUMN location_code    FORMAT A15
COLUMN zone             FORMAT A18
COLUMN capacity         FORMAT 999999
COLUMN used_capacity    FORMAT 999999
COLUMN free_capacity    FORMAT 999999
COLUMN product_ids      FORMAT A20

COLUMN receipt_id       FORMAT 999999
COLUMN supplier_name    FORMAT A25
COLUMN receipt_date     FORMAT A19
COLUMN status           FORMAT A12

COLUMN receipt_line_id  FORMAT 999999
COLUMN product_name     FORMAT A20
COLUMN quantity         FORMAT 999999

COLUMN event_id         FORMAT 999999
COLUMN event_type       FORMAT A24
COLUMN reference_type   FORMAT A15
COLUMN reference_id     FORMAT 999999
COLUMN message          FORMAT A100

COLUMN storage_type     FORMAT A15

DEFINE before_receipt_id = '&1'
DEFINE before_event_id = '&2'

PROMPT ============================================================
PROMPT CURRENT LOCATION CAPACITY AFTER THIS TEST
PROMPT ============================================================

SELECT
    l.location_code,
    l.zone,
    l.capacity,
    l.used_capacity,
    (l.capacity - l.used_capacity) AS free_capacity,
    NVL((
        SELECT LISTAGG(i.product_id, '|')
        WITHIN GROUP (ORDER BY i.product_id)
        FROM inventory i
        WHERE i.location_id = l.location_id
    ), 'NONE') AS product_ids
FROM locations l
ORDER BY l.location_id;

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