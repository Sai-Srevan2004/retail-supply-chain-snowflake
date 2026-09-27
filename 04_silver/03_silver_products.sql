USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


-- ============================================================
-- PRODUCTS
-- ============================================================

CREATE OR REPLACE TABLE SILVER.PRODUCTS (
    product_id       VARCHAR NOT NULL,
    product_name     VARCHAR,
    category         VARCHAR,
    brand            VARCHAR,
    supplier_id      VARCHAR,
    unit_price       NUMBER(12,2),
    created_at       TIMESTAMP_NTZ,
    updated_at       TIMESTAMP_NTZ,

    _source_file     VARCHAR,
    _batch_id        VARCHAR,
    _loaded_at       TIMESTAMP_NTZ
);


-- ============================================================
-- 4A. STANDARDIZE + VALIDATE PRODUCTS
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE PRODUCTS_VALIDATED AS

SELECT
    TRIM(p.product_id) AS product_id,

    NULLIF(TRIM(p.product_name), '') AS product_name,

    UPPER(NULLIF(TRIM(p.category), '')) AS category,

    NULLIF(TRIM(p.brand), '') AS brand,

    TRIM(p.supplier_id) AS supplier_id,

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
        'product_id', p.product_id,
        'product_name', p.product_name,
        'category', p.category,
        'brand', p.brand,
        'supplier_id', p.supplier_id,
        'unit_price', p.unit_price,
        'created_at', p.created_at,
        'updated_at', p.updated_at
    ) AS raw_record,

    CASE
    WHEN NULLIF(TRIM(p.product_id), '') IS NULL
      OR NULLIF(TRIM(p.product_name), '') IS NULL

      OR TRY_TO_DECIMAL(
             NULLIF(TRIM(p.unit_price), ''),
             12,
             2
         ) IS NULL

      OR TRY_TO_DECIMAL(
             NULLIF(TRIM(p.unit_price), ''),
             12,
             2
         ) <= 0

      OR NULLIF(TRIM(p.supplier_id), '') IS NULL

      OR NOT EXISTS (
          SELECT 1
          FROM SILVER.SUPPLIERS s
          WHERE s.supplier_id = TRIM(p.supplier_id)
      )

      OR TRY_TO_TIMESTAMP_NTZ(p.created_at) IS NULL

      OR TRY_TO_TIMESTAMP_NTZ(p.updated_at) IS NULL

    THEN 'INVALID'
    ELSE 'VALID'
END AS validation_status
FROM RAW.PRODUCTS p;


-- ============================================================
-- 4B. REJECT INVALID PRODUCTS
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
    'PRODUCT',
    product_id,
    validation_status,
    raw_record,
    _batch_id
FROM PRODUCTS_VALIDATED
WHERE validation_status <> 'VALID';


-- ============================================================
-- 4C. INSERT VALID + DEDUPLICATED PRODUCTS
-- ============================================================

INSERT INTO SILVER.PRODUCTS (
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
FROM PRODUCTS_VALIDATED
WHERE validation_status = 'VALID'

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY product_id
    ORDER BY
        updated_at DESC NULLS LAST,
        _loaded_at DESC,
        _row_number DESC
) = 1;