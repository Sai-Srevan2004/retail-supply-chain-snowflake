USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


-- ============================================================
-- SALES
-- ============================================================

CREATE OR REPLACE TABLE SILVER.SALES (
    sale_id          VARCHAR NOT NULL,
    customer_id      VARCHAR NOT NULL,
    product_id       VARCHAR NOT NULL,
    store_id         VARCHAR NOT NULL,
    sale_date        DATE,
    quantity         NUMBER,
    unit_price       NUMBER(12,2),
    discount         NUMBER(5,2),
    payment_method   VARCHAR,

    _source_file     VARCHAR,
    _batch_id        VARCHAR,
    _loaded_at       TIMESTAMP_NTZ
);


-- ============================================================
-- 6A. STANDARDIZE + VALIDATE SALES
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE SALES_VALIDATED AS

SELECT
    TRIM(s.sale_id) AS sale_id,

    TRIM(s.customer_id) AS customer_id,

    TRIM(s.product_id) AS product_id,

    TRIM(s.store_id) AS store_id,

    TRY_TO_DATE(s.sale_date) AS sale_date,

    TRY_TO_NUMBER(
        NULLIF(TRIM(s.quantity), '')
    ) AS quantity,

    TRY_TO_DECIMAL(
        NULLIF(TRIM(s.unit_price), ''),
        12,
        2
    ) AS unit_price,

    TRY_TO_DECIMAL(
        NULLIF(TRIM(s.discount), ''),
        5,
        2
    ) AS discount,

    UPPER(NULLIF(TRIM(s.payment_method), '')) AS payment_method,

    s._source_file,
    s._batch_id,
    s._loaded_at,
    s._row_number,

    OBJECT_CONSTRUCT(
        'sale_id', s.sale_id,
        'customer_id', s.customer_id,
        'product_id', s.product_id,
        'store_id', s.store_id,
        'sale_date', s.sale_date,
        'quantity', s.quantity,
        'unit_price', s.unit_price,
        'discount', s.discount,
        'payment_method', s.payment_method
    ) AS raw_record,

   CASE
    WHEN NULLIF(TRIM(s.sale_id), '') IS NULL
      OR NULLIF(TRIM(s.customer_id), '') IS NULL
      OR NULLIF(TRIM(s.product_id), '') IS NULL
      OR NULLIF(TRIM(s.store_id), '') IS NULL

      OR TRY_TO_DATE(s.sale_date) IS NULL

      OR TRY_TO_NUMBER(
             NULLIF(TRIM(s.quantity), '')
         ) IS NULL

      OR TRY_TO_NUMBER(
             NULLIF(TRIM(s.quantity), '')
         ) <= 0

      OR TRY_TO_DECIMAL(
             NULLIF(TRIM(s.unit_price), ''),
             12,
             2
         ) IS NULL

      OR TRY_TO_DECIMAL(
             NULLIF(TRIM(s.unit_price), ''),
             12,
             2
         ) <= 0

      OR TRY_TO_DECIMAL(
             NULLIF(TRIM(s.discount), ''),
             5,
             2
         ) IS NULL

      OR TRY_TO_DECIMAL(
             NULLIF(TRIM(s.discount), ''),
             5,
             2
         ) NOT BETWEEN 0 AND 1

      OR UPPER(NULLIF(TRIM(s.payment_method), ''))
         NOT IN (
             'CASH',
             'CARD',
             'UPI',
             'NET_BANKING',
             'WALLET'
         )

      OR NOT EXISTS (
          SELECT 1
          FROM SILVER.CUSTOMERS c
          WHERE c.customer_id = TRIM(s.customer_id)
      )

      OR NOT EXISTS (
          SELECT 1
          FROM SILVER.PRODUCTS p
          WHERE p.product_id = TRIM(s.product_id)
      )

      OR NOT EXISTS (
          SELECT 1
          FROM SILVER.STORES st
          WHERE st.store_id = TRIM(s.store_id)
      )

    THEN 'INVALID'
    ELSE 'VALID'
END AS validation_status

FROM RAW.SALES s;


-- ============================================================
-- 6B. REJECT INVALID SALES
-- ============================================================

INSERT INTO SILVER.REJECTED_RECORDS (
    source_file,
    entity_name,
    business_key,
    rejection_reason,
    raw_record,
    batch_id
)
SELECT
    _source_file,
    'SALE',
    sale_id,
    validation_status,
    raw_record,
    _batch_id
FROM SALES_VALIDATED
WHERE validation_status <> 'VALID';


-- ============================================================
-- 6C. INSERT VALID + DEDUPLICATED SALES
--
-- No SALES_VALID_DEDUP temporary table.
-- ============================================================

INSERT INTO SILVER.SALES (
    sale_id,
    customer_id,
    product_id,
    store_id,
    sale_date,
    quantity,
    unit_price,
    discount,
    payment_method,
    _source_file,
    _batch_id,
    _loaded_at
)
SELECT
    sale_id,
    customer_id,
    product_id,
    store_id,
    sale_date,
    quantity,
    unit_price,
    discount,
    payment_method,
    _source_file,
    _batch_id,
    _loaded_at
FROM SALES_VALIDATED
WHERE validation_status = 'VALID'

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY sale_id
    ORDER BY
        _loaded_at DESC,
        _row_number DESC
) = 1;
