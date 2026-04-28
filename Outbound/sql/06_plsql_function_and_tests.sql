-- συνάρτηση που ελέγχει αν υπάρχει αρκετό απόθεμα
-- επιστρέφει Y ή N

CREATE OR REPLACE FUNCTION has_sufficient_stock(
    p_product_id IN NUMBER,
    p_quantity IN NUMBER
)
RETURN CHAR
IS
    total_stock NUMBER;
BEGIN
    SELECT NVL(SUM(quantity), 0)
    INTO total_stock
    FROM inventory
    WHERE product_id = p_product_id;

    IF total_stock >= p_quantity THEN
        RETURN 'Y';
    ELSE
        RETURN 'N';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN 'N';
END;
/


-- ==========================================
-- TEST CASES - outbound testing
-- ==========================================

SET SERVEROUTPUT ON;


-- test 1: αρκετό απόθεμα - order 1 (Milk + Yogurt)
-- Milk=50, Yogurt=30 -> ζητάμε 10 + 5 -> πρέπει COMPLETED

PROMPT === TEST 1: enough stock - expected COMPLETED ===

DECLARE
    status_result VARCHAR2(30);
BEGIN
    process_order(1);

    SELECT status INTO status_result
    FROM customer_orders WHERE order_id = 1;

    IF status_result = 'COMPLETED' THEN
        DBMS_OUTPUT.PUT_LINE('TEST 1 OK - ' || status_result);
    ELSE
        DBMS_OUTPUT.PUT_LINE('TEST 1 FAIL - ' || status_result);
    END IF;
END;
/


-- test 2: αρκετό απόθεμα - order 2 (Rice + Pasta)
-- Rice=80, Pasta=60 -> ζητάμε 20 + 15 -> πρέπει COMPLETED

PROMPT === TEST 2: enough stock order 2 - expected COMPLETED ===

DECLARE
    status_result VARCHAR2(30);
BEGIN
    process_order(2);

    SELECT status INTO status_result
    FROM customer_orders WHERE order_id = 2;

    IF status_result = 'COMPLETED' THEN
        DBMS_OUTPUT.PUT_LINE('TEST 2 OK - ' || status_result);
    ELSE
        DBMS_OUTPUT.PUT_LINE('TEST 2 FAIL - ' || status_result);
    END IF;
END;
/


-- test 3: μετά τα COMPLETED τα αποθέματα πρέπει να μειώθηκαν
-- Milk 50-10=40, Yogurt 30-5=25, Rice 80-20=60, Pasta 60-15=45

PROMPT === TEST 3: stock reduced after COMPLETED orders ===

DECLARE
    milk_qty   NUMBER;
    yogurt_qty NUMBER;
    rice_qty   NUMBER;
    pasta_qty  NUMBER;
BEGIN
    SELECT quantity INTO milk_qty   FROM inventory WHERE product_id = 1;
    SELECT quantity INTO yogurt_qty FROM inventory WHERE product_id = 2;
    SELECT quantity INTO rice_qty   FROM inventory WHERE product_id = 4;
    SELECT quantity INTO pasta_qty  FROM inventory WHERE product_id = 5;

    IF milk_qty = 40 AND yogurt_qty = 25 AND rice_qty = 60 AND pasta_qty = 45 THEN
        DBMS_OUTPUT.PUT_LINE('TEST 3 OK - Milk=' || milk_qty || ' Yogurt=' || yogurt_qty || ' Rice=' || rice_qty || ' Pasta=' || pasta_qty);
    ELSE
        DBMS_OUTPUT.PUT_LINE('TEST 3 FAIL - Milk=' || milk_qty || ' Yogurt=' || yogurt_qty || ' Rice=' || rice_qty || ' Pasta=' || pasta_qty);
    END IF;
END;
/


-- test 4: ανεπαρκές απόθεμα - ζητάμε 9999 Milk -> πρέπει FAILED

PROMPT === TEST 4: not enough stock - expected FAILED ===

DECLARE
    v_id NUMBER;
    status_result VARCHAR2(30);
BEGIN
    INSERT INTO customer_orders VALUES (
        seq_customer_orders.NEXTVAL, 'No Stock Customer', SYSDATE, 'RECEIVED'
    ) RETURNING order_id INTO v_id;

    INSERT INTO order_lines VALUES (
        seq_order_lines.NEXTVAL, v_id, 1, 9999
    );
    COMMIT;

    process_order(v_id);

    SELECT status INTO status_result
    FROM customer_orders WHERE order_id = v_id;

    IF status_result = 'FAILED' THEN
        DBMS_OUTPUT.PUT_LINE('TEST 4 OK - ' || status_result);
    ELSE
        DBMS_OUTPUT.PUT_LINE('TEST 4 FAIL - ' || status_result);
    END IF;
END;
/


-- test 5: 2 προϊόντα, το ένα δεν έχει απόθεμα -> πρέπει FAILED

PROMPT === TEST 5: one product missing - expected FAILED ===

DECLARE
    v_id NUMBER;
    status_result VARCHAR2(30);
BEGIN
    INSERT INTO customer_orders VALUES (
        seq_customer_orders.NEXTVAL, 'Partial Stock Customer', SYSDATE, 'RECEIVED'
    ) RETURNING order_id INTO v_id;

    INSERT INTO order_lines VALUES (seq_order_lines.NEXTVAL, v_id, 4, 10);
    INSERT INTO order_lines VALUES (seq_order_lines.NEXTVAL, v_id, 5, 9999);
    COMMIT;

    process_order(v_id);

    SELECT status INTO status_result
    FROM customer_orders WHERE order_id = v_id;

    IF status_result = 'FAILED' THEN
        DBMS_OUTPUT.PUT_LINE('TEST 5 OK - ' || status_result);
    ELSE
        DBMS_OUTPUT.PUT_LINE('TEST 5 FAIL - ' || status_result);
    END IF;
END;
/


-- test 6: ελέγχουμε ότι γράφτηκαν logs

PROMPT === TEST 6: event log entries exist ===

DECLARE
    cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO cnt
    FROM event_log WHERE reference_type = 'ORDER';

    IF cnt > 0 THEN
        DBMS_OUTPUT.PUT_LINE('TEST 6 OK - ' || cnt || ' entries found');
    ELSE
        DBMS_OUTPUT.PUT_LINE('TEST 6 FAIL - no logs found');
    END IF;
END;
/


-- test 7: low stock report - Yogurt=25 κάτω από 30

PROMPT === TEST 7: low stock report ===

DECLARE
    cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO cnt
    FROM (
        SELECT NVL(SUM(i.quantity), 0) AS total
        FROM products p
        LEFT JOIN inventory i ON p.product_id = i.product_id
        GROUP BY p.product_id
        HAVING NVL(SUM(i.quantity), 0) < 30
    );

    IF cnt >= 1 THEN
        DBMS_OUTPUT.PUT_LINE('TEST 7 OK - ' || cnt || ' products below stock limit');
    ELSE
        DBMS_OUTPUT.PUT_LINE('TEST 7 INFO - no products below limit');
    END IF;
END;
/


-- test 8: δοκιμάζουμε την has_sufficient_stock

PROMPT === TEST 8: has_sufficient_stock ===

DECLARE
    res CHAR(1);
BEGIN
    -- Rice=60 -> qty=10 υπάρχει
    res := has_sufficient_stock(4, 10);
    IF res = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('TEST 8a OK - Rice qty=10 returns Y');
    ELSE
        DBMS_OUTPUT.PUT_LINE('TEST 8a FAIL - ' || res);
    END IF;

    -- Rice=60 -> qty=9999 δεν υπάρχει
    res := has_sufficient_stock(4, 9999);
    IF res = 'N' THEN
        DBMS_OUTPUT.PUT_LINE('TEST 8b OK - Rice qty=9999 returns N');
    ELSE
        DBMS_OUTPUT.PUT_LINE('TEST 8b FAIL - ' || res);
    END IF;
END;
/

PROMPT === TESTS DONE ===

EXIT;
