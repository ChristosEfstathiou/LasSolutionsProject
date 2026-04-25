-- procedure για επεξεργασία παραγγελίας
-- ελέγχει απόθεμα, αφαιρεί ποσότητες, ενημερώνει status

CREATE OR REPLACE PROCEDURE process_order(p_order_id IN NUMBER)
IS
    missing_stock NUMBER := 0;
    err_msg VARCHAR2(4000);
    current_status VARCHAR2(30);
BEGIN

    -- ελέγχουμε αν το order υπάρχει και είναι σε RECEIVED status
    SELECT status INTO current_status
    FROM customer_orders
    WHERE order_id = p_order_id;

    IF current_status != 'RECEIVED' THEN
        DBMS_OUTPUT.PUT_LINE('Order ' || p_order_id || ' is already ' || current_status || ' - skipping');
        RETURN;
    END IF;

    -- βάζουμε την παραγγελία σε επεξεργασία
    UPDATE customer_orders
    SET status = 'UNDER_PROCEDURE'
    WHERE order_id = p_order_id;

    -- ελέγχουμε αν υπάρχει αρκετό απόθεμα για κάθε γραμμή
    FOR rec IN (
        SELECT ol.product_id,
               ol.quantity AS needed,
               NVL(SUM(i.quantity), 0) AS available
        FROM order_lines ol
        LEFT JOIN inventory i ON ol.product_id = i.product_id
        WHERE ol.order_id = p_order_id
        GROUP BY ol.product_id, ol.quantity
    )
    LOOP
        IF rec.available < rec.needed THEN
            missing_stock := 1;
        END IF;
    END LOOP;

    -- αν λείπει κάτι, αποτυχία
    IF missing_stock = 1 THEN

        UPDATE customer_orders
        SET status = 'FAILED'
        WHERE order_id = p_order_id;

        INSERT INTO event_log (event_id, event_time, event_type, reference_type, reference_id, message)
        VALUES (seq_event_log.NEXTVAL, SYSDATE, 'ORDER', 'ORDER', p_order_id, 'Order failed due to insufficient stock');

        COMMIT;
        RETURN;
    END IF;

    -- αφαιρούμε το απόθεμα
    FOR rec IN (
        SELECT product_id, quantity
        FROM order_lines
        WHERE order_id = p_order_id
    )
    LOOP
        UPDATE inventory
        SET quantity = quantity - rec.quantity
        WHERE product_id = rec.product_id;
    END LOOP;

    -- ολοκλήρωση παραγγελίας
    UPDATE customer_orders
    SET status = 'COMPLETED'
    WHERE order_id = p_order_id;

    -- log επιτυχίας
    INSERT INTO event_log (event_id, event_time, event_type, reference_type, reference_id, message)
    VALUES (seq_event_log.NEXTVAL, SYSDATE, 'ORDER', 'ORDER', p_order_id, 'Order completed successfully');

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        err_msg := SQLERRM;

        -- καταγράφουμε το σφάλμα
        INSERT INTO event_log (event_id, event_time, event_type, reference_type, reference_id, message)
        VALUES (seq_event_log.NEXTVAL, SYSDATE, 'ERROR', 'ORDER', p_order_id, err_msg);

        COMMIT;
END;
/

EXIT;
