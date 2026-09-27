USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;

CREATE OR REPLACE TEMPORARY TABLE CUSTOMERS_INCREMENTAL_VALIDATED AS

SELECT
    TRIM(r.customer_id) AS customer_id,
    NULLIF(TRIM(r.customer_name), '') AS customer_name,
    LOWER(NULLIF(TRIM(r.email), '')) AS email,
    NULLIF(TRIM(r.phone), '') AS phone,

    UPPER(NULLIF(TRIM(r.region), '')) AS region,
    UPPER(NULLIF(TRIM(r.segment), '')) AS segment,

    TRY_TO_TIMESTAMP_NTZ(r.created_at) AS created_at,
    TRY_TO_TIMESTAMP_NTZ(r.updated_at) AS updated_at,

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

    ARRAY_CONSTRUCT_COMPACT(

        CASE
            WHEN NULLIF(TRIM(r.customer_id), '') IS NULL
            THEN 'MISSING_CUSTOMER_ID'
        END,

        CASE
            WHEN NULLIF(TRIM(r.customer_name), '') IS NULL
            THEN 'MISSING_CUSTOMER_NAME'
        END,

        CASE
            WHEN NULLIF(TRIM(r.email), '') IS NOT NULL
             AND NOT REGEXP_LIKE(
                    TRIM(r.email),
                    '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
                 )
            THEN 'INVALID_EMAIL_FORMAT'
        END,

        CASE
            WHEN NULLIF(TRIM(r.phone), '') IS NOT NULL
             AND NOT REGEXP_LIKE(
                    TRIM(r.phone),
                    '^[0-9+() -]{7,20}$'
                 )
            THEN 'INVALID_PHONE_FORMAT'
        END,

        CASE
            WHEN TRY_TO_TIMESTAMP_NTZ(r.created_at) IS NULL
            THEN 'INVALID_CREATED_AT'
        END,

        CASE
            WHEN TRY_TO_TIMESTAMP_NTZ(r.updated_at) IS NULL
            THEN 'INVALID_UPDATED_AT'
        END

    ) AS rejection_reasons,

    CASE
        WHEN ARRAY_SIZE(rejection_reasons) = 0
        THEN 'VALID'
        ELSE 'INVALID'
    END AS validation_status

FROM RAW.CUSTOMER_STREAM r;


--records to rejection table which are invalid

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
FROM CUSTOMERS_INCREMENTAL_VALIDATED
WHERE validation_status = 'INVALID';


--now merge correct records

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

    FROM CUSTOMERS_INCREMENTAL_VALIDATED

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

WHEN MATCHED
     AND (
            src.updated_at > tgt.updated_at
            OR tgt.updated_at IS NULL
         )

THEN UPDATE SET

    tgt.customer_name = src.customer_name,
    tgt.email         = src.email,
    tgt.phone         = src.phone,
    tgt.region        = src.region,
    tgt.segment       = src.segment,
    tgt.created_at    = src.created_at,
    tgt.updated_at    = src.updated_at,
    tgt._source_file  = src._source_file,
    tgt._batch_id     = src._batch_id,
    tgt._loaded_at    = src._loaded_at

WHEN NOT MATCHED

THEN INSERT (
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

VALUES (
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