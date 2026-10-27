USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;

CREATE TABLE IF NOT EXISTS SILVER.PRODUCTS (
    product_id      STRING NOT NULL,
    product_name    STRING,
    category        STRING,
    brand           STRING,
    unit_price      NUMBER(12,2),
    created_at      TIMESTAMP_NTZ,
    updated_at      TIMESTAMP_NTZ,
    is_active       BOOLEAN,
    _source_file    STRING,
    _batch_id       STRING,
    _loaded_at      TIMESTAMP_NTZ
);


-- ============================================================
-- VALID PRODUCT RECORDS
-- ============================================================

INSERT INTO SILVER.PRODUCTS
(
    product_id,
    product_name,
    category,
    brand,
    unit_price,
    created_at,
    updated_at,
    is_active,
    _source_file,
    _batch_id,
    _loaded_at
)
SELECT
    product_id,
    product_name,
    category,
    brand,
    unit_price,
    created_at,
    updated_at,
    is_active,
    _source_file,
    _batch_id,
    _loaded_at
FROM
(
    SELECT
        NULLIF(TRIM(product_id), '') AS product_id,

        NULLIF(TRIM(product_name), '') AS product_name,

        UPPER(NULLIF(TRIM(category), '')) AS category,

        UPPER(NULLIF(TRIM(brand), '')) AS brand,

        TRY_TO_NUMBER(
            NULLIF(TRIM(unit_price), ''),
            12,
            2
        ) AS unit_price,

        TRY_TO_TIMESTAMP_NTZ(
            NULLIF(TRIM(created_at), '')
        ) AS created_at,

        TRY_TO_TIMESTAMP_NTZ(
            NULLIF(TRIM(updated_at), '')
        ) AS updated_at,

        TRY_TO_BOOLEAN(
            NULLIF(TRIM(is_active), '')
        ) AS is_active,

        _source_file,
        _batch_id,
        _loaded_at,

        ROW_NUMBER() OVER (
            PARTITION BY NULLIF(TRIM(product_id), '')
            ORDER BY
                TRY_TO_TIMESTAMP_NTZ(
                    NULLIF(TRIM(updated_at), '')
                ) DESC NULLS LAST,
                _row_number DESC
        ) AS rn

    FROM RAW.PRODUCTS

    WHERE NULLIF(TRIM(product_id), '') IS NOT NULL

      AND NULLIF(TRIM(product_name), '') IS NOT NULL

      AND TRY_TO_NUMBER(
            NULLIF(TRIM(unit_price), ''),
            12,
            2
          ) > 0

      AND TRY_TO_TIMESTAMP_NTZ(
            NULLIF(TRIM(created_at), '')
          ) IS NOT NULL

      AND TRY_TO_TIMESTAMP_NTZ(
            NULLIF(TRIM(updated_at), '')
          ) IS NOT NULL

      AND TRY_TO_BOOLEAN(
            NULLIF(TRIM(is_active), '')
          ) IS NOT NULL
) x

WHERE rn = 1

  AND NOT EXISTS (
      SELECT 1
      FROM SILVER.PRODUCTS t
      WHERE t.product_id = x.product_id
  );


-- ============================================================
-- REJECTED PRODUCT RECORDS
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

    'PRODUCT',

    NULLIF(TRIM(product_id), ''),

    CASE
        WHEN NULLIF(TRIM(product_id), '') IS NULL
            THEN 'MISSING_PRODUCT_ID'

        WHEN NULLIF(TRIM(product_name), '') IS NULL
            THEN 'MISSING_PRODUCT_NAME'

        WHEN TRY_TO_NUMBER(
                NULLIF(TRIM(unit_price), ''),
                12,
                2
             ) IS NULL
            THEN 'INVALID_UNIT_PRICE'

        WHEN TRY_TO_NUMBER(
                NULLIF(TRIM(unit_price), ''),
                12,
                2
             ) <= 0
            THEN 'INVALID_UNIT_PRICE'

        WHEN TRY_TO_TIMESTAMP_NTZ(
                NULLIF(TRIM(created_at), '')
             ) IS NULL
            THEN 'INVALID_CREATED_AT'

        WHEN TRY_TO_TIMESTAMP_NTZ(
                NULLIF(TRIM(updated_at), '')
             ) IS NULL
            THEN 'INVALID_UPDATED_AT'

        WHEN TRY_TO_BOOLEAN(
                NULLIF(TRIM(is_active), '')
             ) IS NULL
            THEN 'INVALID_IS_ACTIVE'

        ELSE 'INVALID_PRODUCT'
    END,

    OBJECT_CONSTRUCT_KEEP_NULL(
        'product_id', product_id,
        'product_name', product_name,
        'category', category,
        'brand', brand,
        'unit_price', unit_price,
        'created_at', created_at,
        'updated_at', updated_at,
        'is_active', is_active
    ),

    _batch_id,

    CURRENT_TIMESTAMP()

FROM RAW.PRODUCTS

WHERE NULLIF(TRIM(product_id), '') IS NULL

   OR NULLIF(TRIM(product_name), '') IS NULL

   OR TRY_TO_NUMBER(
        NULLIF(TRIM(unit_price), ''),
        12,
        2
      ) IS NULL

   OR TRY_TO_NUMBER(
        NULLIF(TRIM(unit_price), ''),
        12,
        2
      ) <= 0

   OR TRY_TO_TIMESTAMP_NTZ(
        NULLIF(TRIM(created_at), '')
      ) IS NULL

   OR TRY_TO_TIMESTAMP_NTZ(
        NULLIF(TRIM(updated_at), '')
      ) IS NULL

   OR TRY_TO_BOOLEAN(
        NULLIF(TRIM(is_active), '')
      ) IS NULL;