SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
WHENEVER SQLERROR CONTINUE

DEFINE supplier_name = '&1'
DEFINE default_status = '&2'
DEFINE prefer_same_product = '&3'

DECLARE
    v_receipt_id NUMBER;
    v_status VARCHAR2(30);
BEGIN
    BEGIN
        INSERT INTO receipts (
            receipt_id,
            supplier_name,
            receipt_date,
            status
        )
        VALUES (
            seq_receipts.NEXTVAL,
            '&supplier_name',
            SYSDATE,
            '&default_status'
        )
        RETURNING receipt_id INTO v_receipt_id;

        FOR rec IN (
            SELECT
                line_no,
                product_id,
                quantity
            FROM temp_multi_product_receipt_lines
            ORDER BY line_no
        )
        LOOP
            INSERT INTO receipt_lines (
                receipt_line_id,
                receipt_id,
                product_id,
                quantity
            )
            VALUES (
                seq_receipt_lines.NEXTVAL,
                v_receipt_id,
                rec.product_id,
                rec.quantity
            );
        END LOOP;

        COMMIT;

        process_receipt(
            v_receipt_id,
            '&prefer_same_product'
        );

        SELECT status
        INTO v_status
        FROM receipts
        WHERE receipt_id = v_receipt_id;

        DBMS_OUTPUT.PUT_LINE('RECEIPT_ID=' || v_receipt_id);
        DBMS_OUTPUT.PUT_LINE('DB_STATUS=' || v_status);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('DB_STATUS=REJECTED');
            DBMS_OUTPUT.PUT_LINE('DB_ERROR=' || SQLERRM);
    END;
END;
/
EXIT;