USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;

CREATE TABLE IF NOT EXISTS SILVER.CUSTOMERS (
    customer_id     STRING NOT NULL,
    customer_name   STRING,
    email           STRING,
    phone           STRING,
    region          STRING,
    segment         STRING,
    created_at      TIMESTAMP_NTZ,
    updated_at      TIMESTAMP_NTZ,
    _source_file    STRING,
    _batch_id       STRING,
    _loaded_at      TIMESTAMP_NTZ
);


-- ============================================================
-- VALID CUSTOMER RECORDS
-- Cleansing + Type Conversion + Validation + Deduplication
-- ============================================================

INSERT INTO SILVER.CUSTOMERS
(
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
FROM
(
    SELECT
        NULLIF(TRIM(customer_id), '') AS customer_id,

        NULLIF(TRIM(customer_name), '') AS customer_name,

        LOWER(NULLIF(TRIM(email), '')) AS email,

        NULLIF(TRIM(phone), '') AS phone,

        UPPER(NULLIF(TRIM(region), '')) AS region,

        UPPER(NULLIF(TRIM(segment), '')) AS segment,

        TRY_TO_TIMESTAMP_NTZ(
            NULLIF(TRIM(created_at), '')
        ) AS created_at,

        TRY_TO_TIMESTAMP_NTZ(
            NULLIF(TRIM(updated_at), '')
        ) AS updated_at,

        _source_file,
        _batch_id,
        _loaded_at,

        ROW_NUMBER() OVER (
            PARTITION BY NULLIF(TRIM(customer_id), '')
            ORDER BY
                TRY_TO_TIMESTAMP_NTZ(
                    NULLIF(TRIM(updated_at), '')
                ) DESC NULLS LAST,
                _row_number DESC
        ) AS rn

    FROM RAW.CUSTOMERS

    WHERE NULLIF(TRIM(customer_id), '') IS NOT NULL

      AND NULLIF(TRIM(customer_name), '') IS NOT NULL

      AND NULLIF(TRIM(email), '') IS NOT NULL

      AND REGEXP_LIKE(
            LOWER(TRIM(email)),
            '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$'
          )

      AND TRY_TO_TIMESTAMP_NTZ(
            NULLIF(TRIM(created_at), '')
          ) IS NOT NULL

      AND TRY_TO_TIMESTAMP_NTZ(
            NULLIF(TRIM(updated_at), '')
          ) IS NOT NULL
) x

WHERE rn = 1

  AND NOT EXISTS (
      SELECT 1
      FROM SILVER.CUSTOMERS t
      WHERE t.customer_id = x.customer_id
  );


-- ============================================================
-- REJECTED CUSTOMER RECORDS
-- ============================================================

INSERT INTO SILVER.REJECTED_RECORDS
(
    source_file,
    entity_name,
    business_key,
    rejection_reason,
    raw_record,
    batch_id,
    rejected_at
)
SELECT
    _source_file,

    'CUSTOMER',

    NULLIF(TRIM(customer_id), ''),

    CASE
        WHEN NULLIF(TRIM(customer_id), '') IS NULL
            THEN 'MISSING_CUSTOMER_ID'

        WHEN NULLIF(TRIM(customer_name), '') IS NULL
            THEN 'MISSING_CUSTOMER_NAME'

        WHEN NULLIF(TRIM(email), '') IS NULL
            THEN 'MISSING_EMAIL'

        WHEN NOT REGEXP_LIKE(
                LOWER(TRIM(email)),
                '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$'
             )
            THEN 'INVALID_EMAIL'

        WHEN TRY_TO_TIMESTAMP_NTZ(
                NULLIF(TRIM(created_at), '')
             ) IS NULL
            THEN 'INVALID_CREATED_AT'

        WHEN TRY_TO_TIMESTAMP_NTZ(
                NULLIF(TRIM(updated_at), '')
             ) IS NULL
            THEN 'INVALID_UPDATED_AT'

        ELSE 'INVALID_CUSTOMER'
    END,

    OBJECT_CONSTRUCT_KEEP_NULL(
        'customer_id', customer_id,
        'customer_name', customer_name,
        'email', email,
        'phone', phone,
        'region', region,
        'segment', segment,
        'created_at', created_at,
        'updated_at', updated_at
    ),

    _batch_id,

    CURRENT_TIMESTAMP()

FROM RAW.CUSTOMERS

WHERE NULLIF(TRIM(customer_id), '') IS NULL

   OR NULLIF(TRIM(customer_name), '') IS NULL

   OR NULLIF(TRIM(email), '') IS NULL

   OR NOT REGEXP_LIKE(
        LOWER(TRIM(email)),
        '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$'
      )

   OR TRY_TO_TIMESTAMP_NTZ(
        NULLIF(TRIM(created_at), '')
      ) IS NULL

   OR TRY_TO_TIMESTAMP_NTZ(
        NULLIF(TRIM(updated_at), '')
      ) IS NULL;