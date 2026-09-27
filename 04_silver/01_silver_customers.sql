USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;

-- ============================================================
-- CUSTOMERS
-- ============================================================

CREATE OR REPLACE TABLE SILVER.CUSTOMERS (
    customer_id      VARCHAR NOT NULL,
    customer_name    VARCHAR,
    email            VARCHAR,
    phone            VARCHAR,
    region           VARCHAR,
    segment          VARCHAR,
    created_at       TIMESTAMP_NTZ,
    updated_at       TIMESTAMP_NTZ,

    _source_file     VARCHAR,
    _batch_id        VARCHAR,
    _loaded_at       TIMESTAMP_NTZ
);


-- ============================================================
-- 2A. STANDARDIZE + VALIDATE CUSTOMERS
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE CUSTOMERS_VALIDATED AS

SELECT
    TRIM(customer_id) AS customer_id,

    NULLIF(TRIM(customer_name), '') AS customer_name,

    LOWER(NULLIF(TRIM(email), '')) AS email,

    NULLIF(TRIM(phone), '') AS phone,

    UPPER(NULLIF(TRIM(region), '')) AS region,

    UPPER(NULLIF(TRIM(segment), '')) AS segment,

    TRY_TO_TIMESTAMP_NTZ(created_at) AS created_at,

    TRY_TO_TIMESTAMP_NTZ(updated_at) AS updated_at,

    _source_file,
    _batch_id,
    _loaded_at,
    _row_number,

    OBJECT_CONSTRUCT(
        'customer_id', customer_id,
        'customer_name', customer_name,
        'email', email,
        'phone', phone,
        'region', region,
        'segment', segment,
        'created_at', created_at,
        'updated_at', updated_at
    ) AS raw_record,

    CASE
    WHEN NULLIF(TRIM(customer_id), '') IS NULL
      OR NULLIF(TRIM(customer_name), '') IS NULL

      OR (
          NULLIF(TRIM(email), '') IS NOT NULL
          AND NOT REGEXP_LIKE(
              TRIM(email),
              '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
          )
      )

      OR (
          NULLIF(TRIM(phone), '') IS NOT NULL
          AND NOT REGEXP_LIKE(
              TRIM(phone),
              '^[0-9+() -]{7,20}$'
          )
      )

      OR TRY_TO_TIMESTAMP_NTZ(created_at) IS NULL
      OR TRY_TO_TIMESTAMP_NTZ(updated_at) IS NULL

    THEN 'INVALID'
    ELSE 'VALID'
END AS validation_status
FROM RAW.CUSTOMERS;


-- ============================================================
-- 2B. REJECT INVALID CUSTOMERS
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
    'CUSTOMER',
    customer_id,
    validation_status,
    raw_record,
    _batch_id
FROM CUSTOMERS_VALIDATED
WHERE validation_status <> 'VALID';


-- ============================================================
-- 2C. INSERT VALID + DEDUPLICATED CUSTOMERS
--
-- No second temporary table.
-- QUALIFY performs the deduplication directly.
--
-- If the same customer_id appears multiple times:
-- latest updated_at wins.
-- ============================================================

INSERT INTO SILVER.CUSTOMERS (
    customer_id,
    customer_name,
    email,
    phone,
    region,
    segment,
    created_at,
    updated_at,
    _source_file,
    _batch_id,
    _loaded_at
)
SELECT
    customer_id,
    customer_name,
    email,
    phone,
    region,
    segment,
    created_at,
    updated_at,
    _source_file,
    _batch_id,
    _loaded_at
FROM CUSTOMERS_VALIDATED
WHERE validation_status = 'VALID'

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY customer_id
    ORDER BY
        updated_at DESC NULLS LAST,
        _loaded_at DESC,
        _row_number DESC
) = 1;

