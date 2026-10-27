USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;

CREATE TABLE IF NOT EXISTS SILVER.STORES (
    store_id        STRING NOT NULL,
    store_name      STRING,
    city            STRING,
    state           STRING,
    region          STRING,
    store_type      STRING,
    opened_date     DATE,
    _source_file    STRING,
    _batch_id       STRING,
    _loaded_at      TIMESTAMP_NTZ
);


-- ============================================================
-- VALID STORE RECORDS
-- ============================================================

INSERT INTO SILVER.STORES
(
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
FROM
(
    SELECT
        NULLIF(TRIM(store_id), '') AS store_id,

        NULLIF(TRIM(store_name), '') AS store_name,

        NULLIF(TRIM(city), '') AS city,

        UPPER(NULLIF(TRIM(state), '')) AS state,

        UPPER(NULLIF(TRIM(region), '')) AS region,

        UPPER(NULLIF(TRIM(store_type), '')) AS store_type,

        TRY_TO_DATE(
            NULLIF(TRIM(opened_date), '')
        ) AS opened_date,

        _source_file,
        _batch_id,
        _loaded_at,

        ROW_NUMBER() OVER (
            PARTITION BY NULLIF(TRIM(store_id), '')
            ORDER BY
                TRY_TO_DATE(
                    NULLIF(TRIM(opened_date), '')
                ) DESC NULLS LAST,
                _row_number DESC
        ) AS rn

    FROM RAW.STORES

    WHERE NULLIF(TRIM(store_id), '') IS NOT NULL

      AND NULLIF(TRIM(store_name), '') IS NOT NULL

      AND TRY_TO_DATE(
            NULLIF(TRIM(opened_date), '')
          ) IS NOT NULL
) x

WHERE rn = 1

  AND NOT EXISTS (
      SELECT 1
      FROM SILVER.STORES t
      WHERE t.store_id = x.store_id
  );


-- ============================================================
-- REJECTED STORE RECORDS
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

    'STORE',

    NULLIF(TRIM(store_id), ''),

    CASE
        WHEN NULLIF(TRIM(store_id), '') IS NULL
            THEN 'MISSING_STORE_ID'

        WHEN NULLIF(TRIM(store_name), '') IS NULL
            THEN 'MISSING_STORE_NAME'

        WHEN TRY_TO_DATE(
                NULLIF(TRIM(opened_date), '')
             ) IS NULL
            THEN 'INVALID_OPENED_DATE'

        ELSE 'INVALID_STORE'
    END,

    OBJECT_CONSTRUCT_KEEP_NULL(
        'store_id', store_id,
        'store_name', store_name,
        'city', city,
        'state', state,
        'region', region,
        'store_type', store_type,
        'opened_date', opened_date
    ),

    _batch_id,

    CURRENT_TIMESTAMP()

FROM RAW.STORES

WHERE NULLIF(TRIM(store_id), '') IS NULL

   OR NULLIF(TRIM(store_name), '') IS NULL

   OR TRY_TO_DATE(
        NULLIF(TRIM(opened_date), '')
      ) IS NULL;