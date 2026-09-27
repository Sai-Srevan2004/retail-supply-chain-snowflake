USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;

-- ============================================================
-- CUSTOMERS
-- ============================================================

CREATE TABLE IF NOT EXISTS SILVER.CUSTOMERS (
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
-- NOTE: CREATE IF NOT EXISTS.
-- This script now runs repeatedly (once per batch load), so it must not
-- drop/rebuild SILVER.CUSTOMERS every time it runs.


-- ============================================================
-- 2A. STANDARDIZE + VALIDATE CUSTOMERS
--
-- Only process rows from RAW that haven't been promoted to SILVER yet,
-- identified by _batch_id. 
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE CUSTOMERS_VALIDATED AS

SELECT
    r.customer_id                                   AS customer_id_raw,
    TRIM(r.customer_id)                              AS customer_id,

    r.customer_name                                  AS customer_name_raw,
    NULLIF(TRIM(r.customer_name), '')                AS customer_name,

    r.email                                          AS email_raw,
    LOWER(NULLIF(TRIM(r.email), ''))                 AS email,

    r.phone                                          AS phone_raw,
    NULLIF(TRIM(r.phone), '')                        AS phone,

    UPPER(NULLIF(TRIM(r.region), ''))                AS region,
    UPPER(NULLIF(TRIM(r.segment), ''))               AS segment,

    r.created_at                                     AS created_at_raw,
    TRY_TO_TIMESTAMP_NTZ(r.created_at)               AS created_at,

    r.updated_at                                     AS updated_at_raw,
    TRY_TO_TIMESTAMP_NTZ(r.updated_at)               AS updated_at,

    r._source_file,
    r._batch_id,
    r._loaded_at,
    r._row_number,

    OBJECT_CONSTRUCT(
        'customer_id',   r.customer_id,
        'customer_name', r.customer_name,
        'email',         r.email,
        'phone',         r.phone,
        'region',        r.region,
        'segment',       r.segment,
        'created_at',    r.created_at,
        'updated_at',    r.updated_at
    ) AS raw_record,

    -- Per-rule reasons, only the ones that actually failed.
    ARRAY_CONSTRUCT_COMPACT(
        CASE WHEN NULLIF(TRIM(r.customer_id), '') IS NULL
             THEN 'MISSING_CUSTOMER_ID' END,

        CASE WHEN NULLIF(TRIM(r.customer_name), '') IS NULL
             THEN 'MISSING_CUSTOMER_NAME' END,

        CASE WHEN NULLIF(TRIM(r.email), '') IS NOT NULL
              AND NOT REGEXP_LIKE(
                    TRIM(r.email),
                    '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
                  )
             THEN 'INVALID_EMAIL_FORMAT' END,

        CASE WHEN NULLIF(TRIM(r.phone), '') IS NOT NULL
              AND NOT REGEXP_LIKE(
                    TRIM(r.phone),
                    '^[0-9+() -]{7,20}$'
                  )
             THEN 'INVALID_PHONE_FORMAT' END,

        CASE WHEN TRY_TO_TIMESTAMP_NTZ(r.created_at) IS NULL
             THEN 'INVALID_CREATED_AT' END,

        CASE WHEN TRY_TO_TIMESTAMP_NTZ(r.updated_at) IS NULL
             THEN 'INVALID_UPDATED_AT' END
    ) AS rejection_reasons,

    CASE
        WHEN ARRAY_SIZE(rejection_reasons) = 0 THEN 'VALID'
        ELSE 'INVALID'
    END AS validation_status

FROM RAW.CUSTOMERS r

WHERE r._batch_id NOT IN (
    SELECT DISTINCT _batch_id FROM SILVER.CUSTOMERS WHERE _batch_id IS NOT NULL
)

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
    ARRAY_TO_STRING(rejection_reasons, '; '),
    raw_record,
    _batch_id
FROM CUSTOMERS_VALIDATED
WHERE validation_status <> 'VALID';


-- ============================================================
-- 2C. MERGE VALID + DEDUPLICATED CUSTOMERS INTO SILVER
-- ============================================================

MERGE INTO SILVER.CUSTOMERS AS tgt
USING (
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
    ) = 1
) AS src
ON tgt.customer_id = src.customer_id

WHEN MATCHED AND (
        src.updated_at > tgt.updated_at
     OR tgt.updated_at IS NULL
) THEN UPDATE SET
    customer_name = src.customer_name,
    email         = src.email,
    phone         = src.phone,
    region        = src.region,
    segment       = src.segment,
    created_at    = src.created_at,
    updated_at    = src.updated_at,
    _source_file  = src._source_file,
    _batch_id     = src._batch_id,
    _loaded_at    = src._loaded_at

WHEN NOT MATCHED THEN INSERT (
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
) VALUES (
    src.customer_id,
    src.customer_name,
    src.email,
    src.phone,
    src.region,
    src.segment,
    src.created_at,
    src.updated_at,
    src._source_file,
    src._batch_id,
    src._loaded_at
);