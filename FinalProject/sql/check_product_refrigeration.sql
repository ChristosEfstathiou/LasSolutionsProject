-- Remove column headers
SET HEADING OFF
-- Remove "rows selected" messages
SET FEEDBACK OFF
-- Disable variable substitution verification
SET VERIFY OFF

DEFINE product_id = '&1'
DEFINE csv_refrigeration = '&2'

SELECT
    CASE
        WHEN requires_refrigeration = '&csv_refrigeration'
        THEN 'MATCH'
        ELSE 'MISMATCH'
    END
FROM products
WHERE product_id = &product_id;

EXIT;