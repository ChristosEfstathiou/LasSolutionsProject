SET HEADING OFF
SET FEEDBACK OFF
SET VERIFY OFF

DEFINE product_id = '&1'

SELECT
    CASE
        WHEN COUNT(*) = 1 THEN 'EXISTS'
        ELSE 'NOT_FOUND'
    END
FROM products
WHERE product_id = &product_id;

EXIT;