SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 0
SET LINESIZE 500
SET TRIMSPOOL ON
SET TERMOUT OFF
SET VERIFY OFF

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