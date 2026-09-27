USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


CREATE OR REPLACE TEMPORARY TABLE SALES_INCREMENTAL_VALIDATED AS

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

        OBJECT_CONSTRUCT(
            'sale_id',        s.sale_id,
            'customer_id',    s.customer_id,
            'product_id',     s.product_id,
            'store_id',       s.store_id,
            'sale_date',      s.sale_date,
            'quantity',       s.quantity,
            'unit_price',     s.unit_price,
            'discount',       s.discount,
            'payment_method', s.payment_method
        ) AS raw_record

    FROM RAW.SALES_STREAM s
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

        CASE
            WHEN cln.sale_id IS NULL
            THEN 'MISSING_SALE_ID'
        END,

        CASE
            WHEN cln.customer_id IS NULL
            THEN 'MISSING_CUSTOMER_ID'
        END,

        CASE
            WHEN cln.product_id IS NULL
            THEN 'MISSING_PRODUCT_ID'
        END,

        CASE
            WHEN cln.store_id IS NULL
            THEN 'MISSING_STORE_ID'
        END,

        CASE
            WHEN cln.sale_date IS NULL
            THEN 'INVALID_SALE_DATE'
        END,

        CASE
            WHEN cln.quantity IS NULL
            THEN 'INVALID_QUANTITY_FORMAT'
        END,

        CASE
            WHEN cln.quantity IS NOT NULL
             AND cln.quantity <= 0
            THEN 'NON_POSITIVE_QUANTITY'
        END,

        CASE
            WHEN cln.unit_price IS NULL
            THEN 'INVALID_UNIT_PRICE_FORMAT'
        END,

        CASE
            WHEN cln.unit_price IS NOT NULL
             AND cln.unit_price <= 0
            THEN 'NON_POSITIVE_UNIT_PRICE'
        END,

        CASE
            WHEN cln.discount IS NULL
            THEN 'INVALID_DISCOUNT_FORMAT'
        END,

        CASE
            WHEN cln.discount IS NOT NULL
             AND cln.discount NOT BETWEEN 0 AND 1
            THEN 'DISCOUNT_OUT_OF_RANGE'
        END,

        CASE
            WHEN cln.payment_method IS NULL
              OR cln.payment_method NOT IN (
                    'CASH',
                    'COD',
                    'CARD',
                    'UPI',
                    'NET_BANKING',
                    'WALLET'
                 )
            THEN 'INVALID_PAYMENT_METHOD'
        END,

        CASE
            WHEN cln.customer_id IS NOT NULL
             AND NOT EXISTS (
                 SELECT 1
                 FROM SILVER.CUSTOMERS c
                 WHERE c.customer_id = cln.customer_id
             )
            THEN 'UNKNOWN_CUSTOMER_ID'
        END,

        CASE
            WHEN cln.product_id IS NOT NULL
             AND NOT EXISTS (
                 SELECT 1
                 FROM SILVER.PRODUCTS p
                 WHERE p.product_id = cln.product_id
             )
            THEN 'UNKNOWN_PRODUCT_ID'
        END,

        CASE
            WHEN cln.store_id IS NOT NULL
             AND NOT EXISTS (
                 SELECT 1
                 FROM SILVER.STORES st
                 WHERE st.store_id = cln.store_id
             )
            THEN 'UNKNOWN_STORE_ID'
        END

    ) AS rejection_reasons,

    CASE
        WHEN ARRAY_SIZE(rejection_reasons) = 0
        THEN 'VALID'
        ELSE 'INVALID'
    END AS validation_status

FROM cleaned cln;


--reject invalid records
---------------------------

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
FROM SALES_INCREMENTAL_VALIDATED
WHERE validation_status = 'INVALID';


--merge valid records
-----------------------

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

    FROM SALES_INCREMENTAL_VALIDATED

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

    tgt.customer_id    = src.customer_id,
    tgt.product_id     = src.product_id,
    tgt.store_id       = src.store_id,
    tgt.sale_date      = src.sale_date,
    tgt.quantity       = src.quantity,
    tgt.unit_price     = src.unit_price,
    tgt.discount       = src.discount,
    tgt.payment_method = src.payment_method,

    tgt._source_file   = src._source_file,
    tgt._batch_id      = src._batch_id,
    tgt._loaded_at     = src._loaded_at


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

)

VALUES (

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