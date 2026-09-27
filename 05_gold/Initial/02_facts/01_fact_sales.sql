USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA GOLD;


CREATE OR REPLACE TABLE GOLD.FACT_SALES (
    sale_key          NUMBER AUTOINCREMENT,
    sale_id           VARCHAR NOT NULL,

    date_key          NUMBER NOT NULL,

    customer_key      NUMBER NOT NULL,
    product_key       NUMBER NOT NULL,
    supplier_key      NUMBER,
    store_key         NUMBER NOT NULL,

    sale_date         DATE,

    quantity          NUMBER,
    unit_price        NUMBER(12,2),
    discount          NUMBER(5,2),

    gross_amount      NUMBER(14,2),
    discount_amount   NUMBER(14,2),
    net_amount        NUMBER(14,2),

    payment_method    VARCHAR,

    _source_file      VARCHAR,
    _batch_id         VARCHAR,
    _loaded_at        TIMESTAMP_NTZ,

    CONSTRAINT pk_fact_sales
        PRIMARY KEY (sale_key)
);

--load data
------------

INSERT INTO GOLD.FACT_SALES (
    sale_id,
    date_key,

    customer_key,
    product_key,
    supplier_key,
    store_key,

    sale_date,

    quantity,
    unit_price,
    discount,

    gross_amount,
    discount_amount,
    net_amount,

    payment_method,

    _source_file,
    _batch_id,
    _loaded_at
)
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

    s.quantity * s.unit_price
        AS gross_amount,

    s.quantity * s.unit_price * s.discount
        AS discount_amount,

    s.quantity * s.unit_price * (1 - s.discount)
        AS net_amount,

    s.payment_method,

    s._source_file,
    s._batch_id,
    s._loaded_at

FROM SILVER.SALES s

INNER JOIN GOLD.DIM_DATE d
    ON s.sale_date = d.full_date

INNER JOIN GOLD.DIM_CUSTOMER c
    ON s.customer_id = c.customer_id
   AND c.is_current = TRUE

INNER JOIN GOLD.DIM_PRODUCT p
    ON s.product_id = p.product_id

INNER JOIN GOLD.DIM_STORE st
    ON s.store_id = st.store_id;