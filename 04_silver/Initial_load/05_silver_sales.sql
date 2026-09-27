USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


-- ============================================================
-- SALES
--
-- NOTE: this pipeline validates customer_id, product_id and store_id
-- against SILVER.CUSTOMERS / SILVER.PRODUCTS / SILVER.STORES. That
-- means the CUSTOMERS, PRODUCTS and STORES pipelines MUST all run and
-- complete before this one, for the current batch, or every sale
-- referencing a same-batch customer/product/store will be wrongly
-- rejected as an unknown FK. Since PRODUCTS itself depends on SUPPLIERS
-- (see the PRODUCTS pipeline note), the required run order is:
-- SUPPLIERS -> PRODUCTS -> CUSTOMERS -> STORES -> SALES
-- (CUSTOMERS and STORES can run in either order relative to each
-- other, as long as both finish before SALES).
-- ============================================================

CREATE TABLE IF NOT EXISTS SILVER.SALES (
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
-- CREATE OR REPLACE -> CREATE IF NOT EXISTS: this script runs once per
-- batch, so it must not drop/rebuild SILVER.SALES every time.


-- ============================================================
-- 6A. STANDARDIZE + VALIDATE SALES
--
-- Cleaned/cast columns are computed ONCE in the inner CTE (aliased s),
-- then referenced by their CTE alias (cln.*) in the outer validation
-- block - no repeated TRY_TO_DATE/TRY_TO_NUMBER/TRY_TO_DECIMAL calls,
-- and no reliance on lateral column aliasing inside a function call
-- (which caused the 'abc' numeric-cast error in PRODUCTS when a raw
-- column and its cleaned alias shared the same name).
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE SALES_VALIDATED AS

WITH cleaned AS (
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

        -- Built from the raw table alias s.*, so these are the true
        -- original values, not the cleaned/cast ones.
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
        ) AS raw_record

    FROM RAW.SALES s
    WHERE s._batch_id NOT IN (
        SELECT DISTINCT _batch_id FROM SILVER.SALES WHERE _batch_id IS NOT NULL
    )
)

SELECT
    cln.sale_id,
    cln.customer_id,
    cln.product_id,
    cln.store_id,
    cln.sale_date,
    cln.quantity,
    cln.unit_price,
    cln.discount,
    cln.payment_method,
    cln._source_file,
    cln._batch_id,
    cln._loaded_at,
    cln._row_number,
    cln.raw_record,

    ARRAY_CONSTRUCT_COMPACT(
        CASE WHEN cln.sale_id IS NULL
             THEN 'MISSING_SALE_ID' END,

        CASE WHEN cln.customer_id IS NULL
             THEN 'MISSING_CUSTOMER_ID' END,

        CASE WHEN cln.product_id IS NULL
             THEN 'MISSING_PRODUCT_ID' END,

        CASE WHEN cln.store_id IS NULL
             THEN 'MISSING_STORE_ID' END,

        CASE WHEN cln.sale_date IS NULL
             THEN 'INVALID_SALE_DATE' END,

        CASE WHEN cln.quantity IS NULL
             THEN 'INVALID_QUANTITY_FORMAT' END,

        CASE WHEN cln.quantity IS NOT NULL AND cln.quantity <= 0
             THEN 'NON_POSITIVE_QUANTITY' END,

        CASE WHEN cln.unit_price IS NULL
             THEN 'INVALID_UNIT_PRICE_FORMAT' END,

        CASE WHEN cln.unit_price IS NOT NULL AND cln.unit_price <= 0
             THEN 'NON_POSITIVE_UNIT_PRICE' END,

        CASE WHEN cln.discount IS NULL
             THEN 'INVALID_DISCOUNT_FORMAT' END,

        CASE WHEN cln.discount IS NOT NULL
              AND cln.discount NOT BETWEEN 0 AND 1
             THEN 'DISCOUNT_OUT_OF_RANGE' END,

        CASE WHEN cln.payment_method IS NULL
              OR cln.payment_method NOT IN (
                  'CASH','COD','CARD','UPI','NET_BANKING','WALLET'
              )
             THEN 'INVALID_PAYMENT_METHOD' END,

        CASE WHEN cln.customer_id IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM SILVER.CUSTOMERS c
                  WHERE c.customer_id = cln.customer_id
              )
             THEN 'UNKNOWN_CUSTOMER_ID' END,

        CASE WHEN cln.product_id IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM SILVER.PRODUCTS p
                  WHERE p.product_id = cln.product_id
              )
             THEN 'UNKNOWN_PRODUCT_ID' END,

        CASE WHEN cln.store_id IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM SILVER.STORES st
                  WHERE st.store_id = cln.store_id
              )
             THEN 'UNKNOWN_STORE_ID' END
    ) AS rejection_reasons,

    CASE
        WHEN ARRAY_SIZE(rejection_reasons) = 0 THEN 'VALID'
        ELSE 'INVALID'
    END AS validation_status

FROM cleaned cln;


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
    ARRAY_TO_STRING(rejection_reasons, '; '),
    raw_record,
    _batch_id
FROM SALES_VALIDATED
WHERE validation_status <> 'VALID';


-- ============================================================
-- 6C. MERGE VALID + DEDUPLICATED SALES INTO SILVER
--
-- QUALIFY dedupes multiple copies of the same sale_id within this
-- run's batch. SALES has no updated_at column in the source (a sale
-- is normally an immutable fact, not something that gets revised), so
-- the tie-break stays on _loaded_at / _row_number only, and a matched
-- row is unconditionally overwritten - confirm that's the behavior
-- you want if a sale_id can legitimately be corrected/resent later.
-- MERGE makes reruns idempotent: an existing sale_id gets UPDATEd, a
-- new one gets INSERTed.
-- ============================================================

MERGE INTO SILVER.SALES AS tgt
USING (
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
    ) = 1
) AS src
ON tgt.sale_id = src.sale_id

WHEN MATCHED THEN UPDATE SET
    customer_id     = src.customer_id,
    product_id      = src.product_id,
    store_id        = src.store_id,
    sale_date       = src.sale_date,
    quantity        = src.quantity,
    unit_price      = src.unit_price,
    discount        = src.discount,
    payment_method  = src.payment_method,
    _source_file    = src._source_file,
    _batch_id       = src._batch_id,
    _loaded_at      = src._loaded_at

WHEN NOT MATCHED THEN INSERT (
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
) VALUES (
    src.sale_id,
    src.customer_id,
    src.product_id,
    src.store_id,
    src.sale_date,
    src.quantity,
    src.unit_price,
    src.discount,
    src.payment_method,
    src._source_file,
    src._batch_id,
    src._loaded_at
);