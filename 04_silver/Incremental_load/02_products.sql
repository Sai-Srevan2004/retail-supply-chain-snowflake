USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


CREATE OR REPLACE TEMPORARY TABLE PRODUCTS_INCREMENTAL_VALIDATED AS

SELECT
    TRIM(p.product_id) AS product_id,

    NULLIF(TRIM(p.product_name), '') AS product_name,

    UPPER(NULLIF(TRIM(p.category), '')) AS category,

    NULLIF(TRIM(p.brand), '') AS brand,

    NULLIF(TRIM(p.supplier_id), '') AS supplier_id,

    TRY_TO_DECIMAL(
        NULLIF(TRIM(p.unit_price), ''),
        12,
        2
    ) AS unit_price,

    TRY_TO_TIMESTAMP_NTZ(p.created_at) AS created_at,

    TRY_TO_TIMESTAMP_NTZ(p.updated_at) AS updated_at,

    p._source_file,
    p._batch_id,
    p._loaded_at,
    p._row_number,

    OBJECT_CONSTRUCT(
        'product_id',   p.product_id,
        'product_name', p.product_name,
        'category',     p.category,
        'brand',        p.brand,
        'supplier_id',  p.supplier_id,
        'unit_price',   p.unit_price,
        'created_at',   p.created_at,
        'updated_at',   p.updated_at
    ) AS raw_record,

    ARRAY_CONSTRUCT_COMPACT(

        CASE
            WHEN NULLIF(TRIM(p.product_id), '') IS NULL
            THEN 'MISSING_PRODUCT_ID'
        END,

        CASE
            WHEN NULLIF(TRIM(p.product_name), '') IS NULL
            THEN 'MISSING_PRODUCT_NAME'
        END,

        CASE
            WHEN TRY_TO_DECIMAL(
                    NULLIF(TRIM(p.unit_price), ''),
                    12,
                    2
                 ) IS NULL
            THEN 'INVALID_UNIT_PRICE_FORMAT'
        END,

        CASE
            WHEN TRY_TO_DECIMAL(
                    NULLIF(TRIM(p.unit_price), ''),
                    12,
                    2
                 ) IS NOT NULL
             AND TRY_TO_DECIMAL(
                    NULLIF(TRIM(p.unit_price), ''),
                    12,
                    2
                 ) <= 0
            THEN 'NON_POSITIVE_UNIT_PRICE'
        END,

        CASE
            WHEN NULLIF(TRIM(p.supplier_id), '') IS NULL
            THEN 'MISSING_SUPPLIER_ID'
        END,

        CASE
            WHEN NULLIF(TRIM(p.supplier_id), '') IS NOT NULL
             AND NOT EXISTS (
                 SELECT 1
                 FROM SILVER.SUPPLIERS s
                 WHERE s.supplier_id = TRIM(p.supplier_id)
             )
            THEN 'UNKNOWN_SUPPLIER_ID'
        END,

        CASE
            WHEN TRY_TO_TIMESTAMP_NTZ(p.created_at) IS NULL
            THEN 'INVALID_CREATED_AT'
        END,

        CASE
            WHEN TRY_TO_TIMESTAMP_NTZ(p.updated_at) IS NULL
            THEN 'INVALID_UPDATED_AT'
        END

    ) AS rejection_reasons,

    CASE
        WHEN ARRAY_SIZE(rejection_reasons) = 0
        THEN 'VALID'
        ELSE 'INVALID'
    END AS validation_status

FROM RAW.PRODUCT_STREAM p;


--rejected invalid records
----------------------------


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
    'PRODUCT',
    product_id,
    ARRAY_TO_STRING(rejection_reasons, '; '),
    raw_record,
    _batch_id
FROM PRODUCTS_INCREMENTAL_VALIDATED
WHERE validation_status = 'INVALID';


--merger valid records
---------------------

MERGE INTO SILVER.PRODUCTS AS tgt

USING (
    SELECT
        product_id,
        product_name,
        category,
        brand,
        supplier_id,
        unit_price,
        created_at,
        updated_at,
        _source_file,
        _batch_id,
        _loaded_at

    FROM PRODUCTS_INCREMENTAL_VALIDATED

    WHERE validation_status = 'VALID'

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY product_id
        ORDER BY
            updated_at DESC NULLS LAST,
            _loaded_at DESC,
            _row_number DESC
    ) = 1

) AS src

ON tgt.product_id = src.product_id

WHEN MATCHED
     AND (
            src.updated_at > tgt.updated_at
            OR tgt.updated_at IS NULL
         )

THEN UPDATE SET

    tgt.product_name = src.product_name,
    tgt.category     = src.category,
    tgt.brand        = src.brand,
    tgt.supplier_id  = src.supplier_id,
    tgt.unit_price   = src.unit_price,
    tgt.created_at   = src.created_at,
    tgt.updated_at   = src.updated_at,
    tgt._source_file = src._source_file,
    tgt._batch_id    = src._batch_id,
    tgt._loaded_at   = src._loaded_at

WHEN NOT MATCHED

THEN INSERT (
    product_id,
    product_name,
    category,
    brand,
    supplier_id,
    unit_price,
    created_at,
    updated_at,
    _source_file,
    _batch_id,
    _loaded_at
)

VALUES (
    src.product_id,
    src.product_name,
    src.category,
    src.brand,
    src.supplier_id,
    src.unit_price,
    src.created_at,
    src.updated_at,
    src._source_file,
    src._batch_id,
    src._loaded_at
);