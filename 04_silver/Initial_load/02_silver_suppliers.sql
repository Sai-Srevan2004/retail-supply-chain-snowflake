USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


-- ============================================================
-- SUPPLIERS
-- ============================================================

CREATE TABLE IF NOT EXISTS SILVER.SUPPLIERS (
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
-- CREATE IF NOT EXISTS: this script runs once per
-- batch, so it must not drop/rebuild SILVER.SUPPLIERS every time.


-- ============================================================
-- 3A. STANDARDIZE + VALIDATE SUPPLIERS
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE SUPPLIERS_VALIDATED AS

SELECT
    r.supplier_id                              AS supplier_id_raw,
    TRIM(r.supplier_id)                        AS supplier_id,

    r.supplier_name                            AS supplier_name_raw,
    NULLIF(TRIM(r.supplier_name), '')          AS supplier_name,

    r.city                                     AS city_raw,
    NULLIF(TRIM(r.city), '')                   AS city,

    UPPER(NULLIF(TRIM(r.state), ''))           AS state,
    UPPER(NULLIF(TRIM(r.country), ''))         AS country,

    r.contact_email                            AS contact_email_raw,
    LOWER(NULLIF(TRIM(r.contact_email), ''))   AS contact_email,

    r.updated_at                                AS updated_at_raw,
    TRY_TO_TIMESTAMP_NTZ(r.updated_at)          AS updated_at,

    r._source_file,
    r._batch_id,
    r._loaded_at,
    r._row_number,


    OBJECT_CONSTRUCT(
        'supplier_id',    r.supplier_id,
        'supplier_name',  r.supplier_name,
        'city',           r.city,
        'state',          r.state,
        'country',        r.country,
        'contact_email',  r.contact_email,
        'updated_at',     r.updated_at
    ) AS raw_record,

    ARRAY_CONSTRUCT_COMPACT(
        CASE WHEN NULLIF(TRIM(r.supplier_id), '') IS NULL
             THEN 'MISSING_SUPPLIER_ID' END,

        CASE WHEN NULLIF(TRIM(r.supplier_name), '') IS NULL
             THEN 'MISSING_SUPPLIER_NAME' END,

        CASE WHEN NULLIF(TRIM(r.contact_email), '') IS NOT NULL
              AND NOT REGEXP_LIKE(
                    TRIM(r.contact_email),
                    '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
                  )
             THEN 'INVALID_EMAIL_FORMAT' END,

        CASE WHEN TRY_TO_TIMESTAMP_NTZ(r.updated_at) IS NULL
             THEN 'INVALID_UPDATED_AT' END
    ) AS rejection_reasons,

    CASE
        WHEN ARRAY_SIZE(rejection_reasons) = 0 THEN 'VALID'
        ELSE 'INVALID'
    END AS validation_status

FROM RAW.SUPPLIERS r
WHERE r._batch_id NOT IN (
    SELECT DISTINCT _batch_id FROM SILVER.SUPPLIERS WHERE _batch_id IS NOT NULL
);


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
    ARRAY_TO_STRING(rejection_reasons, '; '),
    raw_record,
    _batch_id
FROM SUPPLIERS_VALIDATED
WHERE validation_status <> 'VALID';


-- ============================================================
-- 3C. MERGE VALID + DEDUPLICATED SUPPLIERS INTO SILVER

-- ============================================================

MERGE INTO SILVER.SUPPLIERS AS tgt
USING (
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
    ) = 1
) AS src
ON tgt.supplier_id = src.supplier_id

WHEN MATCHED AND (
        src.updated_at > tgt.updated_at
     OR tgt.updated_at IS NULL
) THEN UPDATE SET
    supplier_name = src.supplier_name,
    city          = src.city,
    state         = src.state,
    country       = src.country,
    contact_email = src.contact_email,
    updated_at    = src.updated_at,
    _source_file  = src._source_file,
    _batch_id     = src._batch_id,
    _loaded_at    = src._loaded_at

WHEN NOT MATCHED THEN INSERT (
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
) VALUES (
    src.supplier_id,
    src.supplier_name,
    src.city,
    src.state,
    src.country,
    src.contact_email,
    src.updated_at,
    src._source_file,
    src._batch_id,
    src._loaded_at
);