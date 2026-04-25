-- Remove column headers
SET HEADING OFF
-- Remove "rows selected" messages
SET FEEDBACK OFF
-- Remove page breaks and titles
SET PAGESIZE 0
-- Increase line size to avoid wrapping
SET LINESIZE 500
-- Remove trailing spaces in spooled output
SET TRIMSPOOL ON
-- Disable terminal output for cleaner spooled file
SET TERMOUT OFF
-- Disable variable substitution verification
SET VERIFY OFF

-- Write query output to CSV file
SPOOL logs/cpp_locations_from_db.csv

SELECT 'location_id,location_code,is_refrigerated,capacity,used_capacity,product_ids'
FROM dual;

SELECT
    l.location_id || ',' ||
    l.location_code || ',' ||
    l.is_refrigerated || ',' ||
    l.capacity || ',' ||
    l.used_capacity || ',' ||
    NVL((
        SELECT LISTAGG(product_id, '|') WITHIN GROUP (ORDER BY product_id)
        FROM inventory i
        WHERE i.location_id = l.location_id
    ), 'NONE')
FROM locations l
ORDER BY l.location_id;

SPOOL OFF
EXIT;