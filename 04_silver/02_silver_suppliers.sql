USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


-- ============================================================
-- SUPPLIERS
-- ============================================================

CREATE OR REPLACE TABLE SILVER.SUPPLIERS (
    supplier_id       VARCHAR NOT NULL,
    supplier_name     VARCHAR,
    city              VARCHAR,
    state             VARCHAR,
    country           VARCHAR,
    contact_email     VARCHAR,
    updated_at        TIMESTAMP_NTZ,

    _source_file      VARCHAR,
    _batch_id         VARCHAR,
    _loaded_at        TIMESTAMP_NTZ
);


-- ============================================================
-- 3A. STANDARDIZE + VALIDATE SUPPLIERS
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE SUPPLIERS_VALIDATED AS

SELECT
    TRIM(supplier_id) AS supplier_id,

    NULLIF(TRIM(supplier_name), '') AS supplier_name,

    NULLIF(TRIM(city), '') AS city,

    UPPER(NULLIF(TRIM(state), '')) AS state,

    UPPER(NULLIF(TRIM(country), '')) AS country,

    LOWER(NULLIF(TRIM(contact_email), '')) AS contact_email,

    TRY_TO_TIMESTAMP_NTZ(updated_at) AS updated_at,

    _source_file,
    _batch_id,
    _loaded_at,
    _row_number,

    OBJECT_CONSTRUCT(
        'supplier_id', supplier_id,
        'supplier_name', supplier_name,
        'city', city,
        'state', state,
        'country', country,
        'contact_email', contact_email,
        'updated_at', updated_at
    ) AS raw_record,

    CASE
    WHEN NULLIF(TRIM(supplier_id), '') IS NULL
      OR NULLIF(TRIM(supplier_name), '') IS NULL

      OR (
          NULLIF(TRIM(contact_email), '') IS NOT NULL
          AND NOT REGEXP_LIKE(
              TRIM(contact_email),
              '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
          )
      )

      OR TRY_TO_TIMESTAMP_NTZ(updated_at) IS NULL

    THEN 'INVALID'
    ELSE 'VALID'
END AS validation_status

FROM RAW.SUPPLIERS;


-- ============================================================
-- 3B. REJECT INVALID SUPPLIERS
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
    'SUPPLIER',
    supplier_id,
    validation_status,
    raw_record,
    _batch_id
FROM SUPPLIERS_VALIDATED
WHERE validation_status <> 'VALID';


-- ============================================================
-- 3C. INSERT VALID + DEDUPLICATED SUPPLIERS
-- ============================================================

INSERT INTO SILVER.SUPPLIERS (
    supplier_id,
    supplier_name,
    city,
    state,
    country,
    contact_email,
    updated_at,
    _source_file,
    _batch_id,
    _loaded_at
)
SELECT
    supplier_id,
    supplier_name,
    city,
    state,
    country,
    contact_email,
    updated_at,
    _source_file,
    _batch_id,
    _loaded_at
FROM SUPPLIERS_VALIDATED
WHERE validation_status = 'VALID'

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY supplier_id
    ORDER BY
        updated_at DESC NULLS LAST,
        _loaded_at DESC,
        _row_number DESC
) = 1;
