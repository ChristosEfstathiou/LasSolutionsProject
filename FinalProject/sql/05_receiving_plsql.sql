CREATE OR REPLACE PROCEDURE log_event (
    p_event_type     IN VARCHAR2,
    p_reference_type IN VARCHAR2,
    p_reference_id   IN NUMBER,
    p_message        IN VARCHAR2
)
AS
BEGIN
    INSERT INTO event_log (
        event_id,
        event_time,
        event_type,
        reference_type,
        reference_id,
        message
    )
    VALUES (
        seq_event_log.NEXTVAL,
        SYSDATE,
        p_event_type,
        p_reference_type,
        p_reference_id,
        p_message
    );
END;
/

CREATE OR REPLACE FUNCTION find_putaway_location (
    p_product_id            IN NUMBER,
    p_quantity              IN NUMBER,
    p_prefer_same_product   IN CHAR DEFAULT 'Y'
)
RETURN NUMBER
AS
    v_requires_refrigeration products.requires_refrigeration%TYPE;
    v_location_id locations.location_id%TYPE;
BEGIN
    SELECT requires_refrigeration
    INTO v_requires_refrigeration
    FROM products
    WHERE product_id = p_product_id;

    -- Rule 1:
    -- If config says Y, prefer locations that already contain the same product.
    -- Still uses best-fit among same-product locations.
    IF p_prefer_same_product = 'Y' THEN
        BEGIN
            SELECT location_id
            INTO v_location_id
            FROM (
                SELECT
                    l.location_id,
                    l.capacity - l.used_capacity AS free_capacity
                FROM inventory i
                JOIN locations l ON l.location_id = i.location_id
                WHERE i.product_id = p_product_id
                  AND l.is_refrigerated = v_requires_refrigeration
                  AND l.capacity - l.used_capacity >= p_quantity
                ORDER BY free_capacity ASC, l.location_id ASC
            )
            WHERE ROWNUM = 1;

            RETURN v_location_id;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;
    END IF;

    -- Rule 2:
    -- If same-product preference is disabled, or no same-product location fits,
    -- choose the best-fit compatible location.
    BEGIN
        SELECT location_id
        INTO v_location_id
        FROM (
            SELECT
                l.location_id,
                l.capacity - l.used_capacity AS free_capacity
            FROM locations l
            WHERE l.is_refrigerated = v_requires_refrigeration
              AND l.capacity - l.used_capacity >= p_quantity
            ORDER BY free_capacity ASC, l.location_id ASC
        )
        WHERE ROWNUM = 1;

        RETURN v_location_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END;
END;
/

CREATE OR REPLACE PROCEDURE process_receipt (
    p_receipt_id            IN NUMBER,
    p_prefer_same_product   IN CHAR DEFAULT 'Y'
)
AS
    v_location_id NUMBER;
    v_existing_count NUMBER;
BEGIN
    log_event(
        'RECEIPT_PROCESS_START',
        'RECEIPT',
        p_receipt_id,
        'Started processing receipt ' || p_receipt_id
    );

    FOR rec IN (
        SELECT
            rl.receipt_line_id,
            rl.product_id,
            p.product_name,
            rl.quantity
        FROM receipt_lines rl
        JOIN products p ON p.product_id = rl.product_id
        WHERE rl.receipt_id = p_receipt_id
    )
    LOOP
        v_location_id := find_putaway_location(
            rec.product_id,
            rec.quantity,
            p_prefer_same_product
        );

        IF v_location_id IS NULL THEN
            UPDATE receipts
            SET status = 'FAILED'
            WHERE receipt_id = p_receipt_id;

            log_event(
                'RECEIPT_FAILED',
                'RECEIPT',
                p_receipt_id,
                'No suitable location found for product ' || rec.product_name
            );

            COMMIT;
            RETURN;
        END IF;

        SELECT COUNT(*)
        INTO v_existing_count
        FROM inventory
        WHERE product_id = rec.product_id
          AND location_id = v_location_id;

        IF v_existing_count > 0 THEN
            UPDATE inventory
            SET quantity = quantity + rec.quantity
            WHERE product_id = rec.product_id
              AND location_id = v_location_id;
        ELSE
            INSERT INTO inventory (
                inventory_id,
                product_id,
                location_id,
                quantity
            )
            VALUES (
                seq_inventory.NEXTVAL,
                rec.product_id,
                v_location_id,
                rec.quantity
            );
        END IF;

        UPDATE locations
        SET used_capacity = used_capacity + rec.quantity
        WHERE location_id = v_location_id;

        log_event(
            'PRODUCT_STORED',
            'RECEIPT',
            p_receipt_id,
            'Stored ' || rec.quantity || ' units of ' || rec.product_name ||
            ' in location ID ' || v_location_id ||
            ' using prefer_same_product=' || p_prefer_same_product
        );
    END LOOP;

    UPDATE receipts
    SET status = 'PROCESSED'
    WHERE receipt_id = p_receipt_id;

    log_event(
        'RECEIPT_PROCESSED',
        'RECEIPT',
        p_receipt_id,
        'Receipt ' || p_receipt_id || ' processed successfully'
    );

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;

        UPDATE receipts
        SET status = 'FAILED'
        WHERE receipt_id = p_receipt_id;

        log_event(
            'RECEIPT_ERROR',
            'RECEIPT',
            p_receipt_id,
            'Error while processing receipt: ' || SQLERRM
        );

        COMMIT;
END;
/