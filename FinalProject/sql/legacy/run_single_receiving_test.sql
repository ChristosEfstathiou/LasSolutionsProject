SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
WHENEVER SQLERROR CONTINUE

DEFINE test_id = '&1'
DEFINE product_id = '&2'
DEFINE quantity = '&3'
DEFINE expected_status = '&4'
DEFINE description = '&5'

DECLARE
    v_receipt_id NUMBER;
    v_actual_status VARCHAR2(30);
    v_result VARCHAR2(10);
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
            'CSV Test Supplier',
            SYSDATE,
            'RECEIVED'
        )
        RETURNING receipt_id INTO v_receipt_id;

        INSERT INTO receipt_lines (
            receipt_line_id,
            receipt_id,
            product_id,
            quantity
        )
        VALUES (
            seq_receipt_lines.NEXTVAL,
            v_receipt_id,
            &product_id,
            &quantity
        );

        COMMIT;

        process_receipt(v_receipt_id);

        SELECT status
        INTO v_actual_status
        FROM receipts
        WHERE receipt_id = v_receipt_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            v_actual_status := 'REJECTED';
    END;

    IF v_actual_status = '&expected_status' THEN
        v_result := 'PASS';
    ELSE
        v_result := 'FAIL';
    END IF;

    DBMS_OUTPUT.PUT_LINE(
        RPAD('&test_id', 8) || ' | ' ||
        RPAD(v_result, 6) || ' | ' ||
        RPAD('&expected_status', 12) || ' | ' ||
        RPAD(v_actual_status, 12) || ' | ' ||
        '&description'
    );
END;
/
EXIT;