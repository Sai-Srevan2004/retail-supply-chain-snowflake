USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


-- ============================================================
-- STORES
-- ============================================================

CREATE OR REPLACE TABLE SILVER.STORES (
    store_id         VARCHAR NOT NULL,
    store_name       VARCHAR,
    city             VARCHAR,
    state            VARCHAR,
    region           VARCHAR,
    store_type       VARCHAR,
    opened_date      DATE,

    _source_file     VARCHAR,
    _batch_id        VARCHAR,
    _loaded_at       TIMESTAMP_NTZ
);


-- ============================================================
-- 5A. STANDARDIZE + VALIDATE STORES
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE STORES_VALIDATED AS

SELECT
    TRIM(store_id) AS store_id,

    NULLIF(TRIM(store_name), '') AS store_name,

    NULLIF(TRIM(city), '') AS city,

    UPPER(NULLIF(TRIM(state), '')) AS state,

    UPPER(NULLIF(TRIM(region), '')) AS region,

    UPPER(NULLIF(TRIM(store_type), '')) AS store_type,

    TRY_TO_DATE(opened_date) AS opened_date,

    _source_file,
    _batch_id,
    _loaded_at,
    _row_number,

    OBJECT_CONSTRUCT(
        'store_id', store_id,
        'store_name', store_name,
        'city', city,
        'state', state,
        'region', region,
        'store_type', store_type,
        'opened_date', opened_date
    ) AS raw_record,

    CASE
    WHEN NULLIF(TRIM(store_id), '') IS NULL
      OR NULLIF(TRIM(store_name), '') IS NULL
      OR TRY_TO_DATE(opened_date) IS NULL

    THEN 'INVALID'
    ELSE 'VALID'
END AS validation_status

FROM RAW.STORES;


-- ============================================================
-- 5B. REJECT INVALID STORES
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
    'STORE',
    store_id,
    validation_status,
    raw_record,
    _batch_id
FROM STORES_VALIDATED
WHERE validation_status <> 'VALID';


-- ============================================================
-- 5C. INSERT VALID + DEDUPLICATED STORES
-- ============================================================

INSERT INTO SILVER.STORES (
    store_id,
    store_name,
    city,
    state,
    region,
    store_type,
    opened_date,
    _source_file,
    _batch_id,
    _loaded_at
)
SELECT
    store_id,
    store_name,
    city,
    state,
    region,
    store_type,
    opened_date,
    _source_file,
    _batch_id,
    _loaded_at
FROM STORES_VALIDATED
WHERE validation_status = 'VALID'

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY store_id
    ORDER BY
        _loaded_at DESC,
        _row_number DESC
) = 1;
