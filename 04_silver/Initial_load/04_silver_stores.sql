USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


-- ============================================================
-- STORES
-- ============================================================

CREATE TABLE IF NOT EXISTS SILVER.STORES (
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
-- CREATE IF NOT EXISTS: this script runs once per
-- batch, so it must not drop/rebuild SILVER.STORES every time.


-- ============================================================
-- 5A. STANDARDIZE + VALIDATE STORES
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE STORES_VALIDATED AS

WITH cleaned AS (
    SELECT
        TRIM(s.store_id) AS store_id,

        NULLIF(TRIM(s.store_name), '') AS store_name,

        NULLIF(TRIM(s.city), '') AS city,

        UPPER(NULLIF(TRIM(s.state), '')) AS state,

        UPPER(NULLIF(TRIM(s.region), '')) AS region,

        UPPER(NULLIF(TRIM(s.store_type), '')) AS store_type,

        TRY_TO_DATE(s.opened_date) AS opened_date,

        s._source_file,
        s._batch_id,
        s._loaded_at,
        s._row_number,

        OBJECT_CONSTRUCT(
            'store_id', s.store_id,
            'store_name', s.store_name,
            'city', s.city,
            'state', s.state,
            'region', s.region,
            'store_type', s.store_type,
            'opened_date', s.opened_date
        ) AS raw_record

    FROM RAW.STORES s
    WHERE s._batch_id NOT IN (
        SELECT DISTINCT _batch_id FROM SILVER.STORES WHERE _batch_id IS NOT NULL
    )
)

SELECT
    cln.store_id,
    cln.store_name,
    cln.city,
    cln.state,
    cln.region,
    cln.store_type,
    cln.opened_date,
    cln._source_file,
    cln._batch_id,
    cln._loaded_at,
    cln._row_number,
    cln.raw_record,

    ARRAY_CONSTRUCT_COMPACT(
        CASE WHEN cln.store_id IS NULL
             THEN 'MISSING_STORE_ID' END,

        CASE WHEN cln.store_name IS NULL
             THEN 'MISSING_STORE_NAME' END,

        CASE WHEN cln.opened_date IS NULL
             THEN 'INVALID_OPENED_DATE' END
    ) AS rejection_reasons,

    CASE
        WHEN ARRAY_SIZE(rejection_reasons) = 0 THEN 'VALID'
        ELSE 'INVALID'
    END AS validation_status

FROM cleaned cln;


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
    ARRAY_TO_STRING(rejection_reasons, '; '),
    raw_record,
    _batch_id
FROM STORES_VALIDATED
WHERE validation_status <> 'VALID';


-- ============================================================
-- 5C. MERGE VALID + DEDUPLICATED STORES INTO SILVER
-- ============================================================

MERGE INTO SILVER.STORES AS tgt
USING (
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
    ) = 1
) AS src
ON tgt.store_id = src.store_id

WHEN MATCHED THEN UPDATE SET
    store_name    = src.store_name,
    city          = src.city,
    state         = src.state,
    region        = src.region,
    store_type    = src.store_type,
    opened_date   = src.opened_date,
    _source_file  = src._source_file,
    _batch_id     = src._batch_id,
    _loaded_at    = src._loaded_at

WHEN NOT MATCHED THEN INSERT (
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
) VALUES (
    src.store_id,
    src.store_name,
    src.city,
    src.state,
    src.region,
    src.store_type,
    src.opened_date,
    src._source_file,
    src._batch_id,
    src._loaded_at
);