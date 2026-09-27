USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA GOLD;



MERGE INTO GOLD.FACT_SALES AS tgt
USING (
    SELECT
        s.sale_id,
        d.date_key,
        c.customer_key,
        p.product_key,
        p.supplier_key,
        st.store_key,
        s.sale_date,
        s.quantity,
        s.unit_price,
        s.discount,
        s.quantity * s.unit_price                       AS gross_amount,
        s.quantity * s.unit_price * s.discount           AS discount_amount,
        s.quantity * s.unit_price * (1 - s.discount)     AS net_amount,
        s.payment_method,
        s._source_file,
        s._batch_id,
        s._loaded_at
    FROM SILVER.SALES_STREAM s

    INNER JOIN GOLD.DIM_DATE d
        ON s.sale_date = d.full_date

    INNER JOIN GOLD.DIM_CUSTOMER c
        ON s.customer_id = c.customer_id
       AND c.is_current = TRUE

    INNER JOIN GOLD.DIM_PRODUCT p
        ON s.product_id = p.product_id

    INNER JOIN GOLD.DIM_STORE st
        ON s.store_id = st.store_id

    WHERE s.METADATA$ACTION = 'INSERT'
) AS src
ON tgt.sale_id = src.sale_id

WHEN MATCHED THEN UPDATE SET
    date_key         = src.date_key,
    customer_key     = src.customer_key,
    product_key      = src.product_key,
    supplier_key     = src.supplier_key,
    store_key        = src.store_key,
    sale_date        = src.sale_date,
    quantity         = src.quantity,
    unit_price       = src.unit_price,
    discount         = src.discount,
    gross_amount     = src.gross_amount,
    discount_amount  = src.discount_amount,
    net_amount       = src.net_amount,
    payment_method   = src.payment_method,
    _source_file     = src._source_file,
    _batch_id        = src._batch_id,
    _loaded_at       = src._loaded_at

WHEN NOT MATCHED THEN INSERT (
    sale_id, date_key, customer_key, product_key, supplier_key, store_key,
    sale_date, quantity, unit_price, discount,
    gross_amount, discount_amount, net_amount,
    payment_method, _source_file, _batch_id, _loaded_at
) VALUES (
    src.sale_id, src.date_key, src.customer_key, src.product_key,
    src.supplier_key, src.store_key,
    src.sale_date, src.quantity, src.unit_price, src.discount,
    src.gross_amount, src.discount_amount, src.net_amount,
    src.payment_method, src._source_file, src._batch_id, src._loaded_at
);

