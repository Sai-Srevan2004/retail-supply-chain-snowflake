USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;

CREATE TABLE IF NOT EXISTS SILVER.SALES (
    sale_id           STRING NOT NULL,
    sale_timestamp    TIMESTAMP_NTZ,
    customer_id       STRING,
    product_id        STRING,
    store_id          STRING,
    quantity          NUMBER,
    unit_price        NUMBER(12,2),
    discount_amount   NUMBER(12,2),
    payment_method    STRING,
    _source_file      STRING,
    _batch_id         STRING,
    _loaded_at        TIMESTAMP_NTZ
);


-- ============================================================
-- VALID SALES RECORDS
-- ============================================================

INSERT INTO SILVER.SALES
(
    sale_id,
    sale_timestamp,
    customer_id,
    product_id,
    store_id,
    quantity,
    unit_price,
    discount_amount,
    payment_method,
    _source_file,
    _batch_id,
    _loaded_at
)
SELECT
    sale_id,
    sale_timestamp,
    customer_id,
    product_id,
    store_id,
    quantity,
    unit_price,
    discount_amount,
    payment_method,
    _source_file,
    _batch_id,
    _loaded_at
FROM
(
    SELECT
        NULLIF(TRIM(sale_id), '') AS sale_id,

        TRY_TO_TIMESTAMP_NTZ(
            NULLIF(TRIM(sale_timestamp), '')
        ) AS sale_timestamp,

        NULLIF(TRIM(customer_id), '') AS customer_id,

        NULLIF(TRIM(product_id), '') AS product_id,

        NULLIF(TRIM(store_id), '') AS store_id,

        TRY_TO_NUMBER(
            NULLIF(TRIM(quantity), '')
        ) AS quantity,

        TRY_TO_NUMBER(
            NULLIF(TRIM(unit_price), ''),
            12,
            2
        ) AS unit_price,

        TRY_TO_NUMBER(
            NULLIF(TRIM(discount_amount), ''),
            12,
            2
        ) AS discount_amount,

        UPPER(NULLIF(TRIM(payment_method), '')) AS payment_method,

        _source_file,
        _batch_id,
        _loaded_at,

        ROW_NUMBER() OVER (
            PARTITION BY NULLIF(TRIM(sale_id), '')
            ORDER BY
                TRY_TO_TIMESTAMP_NTZ(
                    NULLIF(TRIM(sale_timestamp), '')
                ) DESC NULLS LAST,
                _row_number DESC
        ) AS rn

    FROM RAW.SALES

    WHERE NULLIF(TRIM(sale_id), '') IS NOT NULL

      AND TRY_TO_TIMESTAMP_NTZ(
            NULLIF(TRIM(sale_timestamp), '')
          ) IS NOT NULL

      AND NULLIF(TRIM(customer_id), '') IS NOT NULL

      AND NULLIF(TRIM(product_id), '') IS NOT NULL

      AND NULLIF(TRIM(store_id), '') IS NOT NULL

      AND TRY_TO_NUMBER(
            NULLIF(TRIM(quantity), '')
          ) > 0

      AND TRY_TO_NUMBER(
            NULLIF(TRIM(unit_price), ''),
            12,
            2
          ) > 0

      AND TRY_TO_NUMBER(
            NULLIF(TRIM(discount_amount), ''),
            12,
            2
          ) >= 0

      AND TRY_TO_NUMBER(
            NULLIF(TRIM(discount_amount), ''),
            12,
            2
          )
          <=
          TRY_TO_NUMBER(
              NULLIF(TRIM(quantity), '')
          )
          *
          TRY_TO_NUMBER(
              NULLIF(TRIM(unit_price), ''),
              12,
              2
          )

      AND UPPER(TRIM(payment_method))
          IN ('CASH', 'CARD', 'UPI', 'WALLET')
) x

WHERE rn = 1

  AND NOT EXISTS (
      SELECT 1
      FROM SILVER.SALES t
      WHERE t.sale_id = x.sale_id
  );


-- ============================================================
-- REJECTED SALES RECORDS
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

    'SALE',

    NULLIF(TRIM(sale_id), ''),

    CASE
        WHEN NULLIF(TRIM(sale_id), '') IS NULL
            THEN 'MISSING_SALE_ID'

        WHEN TRY_TO_TIMESTAMP_NTZ(
                NULLIF(TRIM(sale_timestamp), '')
             ) IS NULL
            THEN 'INVALID_SALE_TIMESTAMP'

        WHEN NULLIF(TRIM(customer_id), '') IS NULL
            THEN 'MISSING_CUSTOMER_ID'

        WHEN NULLIF(TRIM(product_id), '') IS NULL
            THEN 'MISSING_PRODUCT_ID'

        WHEN NULLIF(TRIM(store_id), '') IS NULL
            THEN 'MISSING_STORE_ID'

        WHEN TRY_TO_NUMBER(
                NULLIF(TRIM(quantity), '')
             ) IS NULL
            THEN 'INVALID_QUANTITY'

        WHEN TRY_TO_NUMBER(
                NULLIF(TRIM(quantity), '')
             ) <= 0
            THEN 'INVALID_QUANTITY'

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

        WHEN TRY_TO_NUMBER(
                NULLIF(TRIM(discount_amount), ''),
                12,
                2
             ) IS NULL
            THEN 'INVALID_DISCOUNT'

        WHEN TRY_TO_NUMBER(
                NULLIF(TRIM(discount_amount), ''),
                12,
                2
             ) < 0
            THEN 'INVALID_DISCOUNT'

        WHEN TRY_TO_NUMBER(
                NULLIF(TRIM(discount_amount), ''),
                12,
                2
             )
             >
             TRY_TO_NUMBER(
                 NULLIF(TRIM(quantity), '')
             )
             *
             TRY_TO_NUMBER(
                 NULLIF(TRIM(unit_price), ''),
                 12,
                 2
             )
            THEN 'DISCOUNT_EXCEEDS_GROSS_AMOUNT'

        WHEN UPPER(TRIM(payment_method))
             NOT IN ('CASH', 'CARD', 'UPI', 'WALLET')
            THEN 'INVALID_PAYMENT_METHOD'

        ELSE 'INVALID_SALE'
    END,

    OBJECT_CONSTRUCT_KEEP_NULL(
        'sale_id', sale_id,
        'sale_timestamp', sale_timestamp,
        'customer_id', customer_id,
        'product_id', product_id,
        'store_id', store_id,
        'quantity', quantity,
        'unit_price', unit_price,
        'discount_amount', discount_amount,
        'payment_method', payment_method
    ),

    _batch_id,

    CURRENT_TIMESTAMP()

FROM RAW.SALES

WHERE NULLIF(TRIM(sale_id), '') IS NULL

   OR TRY_TO_TIMESTAMP_NTZ(
        NULLIF(TRIM(sale_timestamp), '')
      ) IS NULL

   OR NULLIF(TRIM(customer_id), '') IS NULL

   OR NULLIF(TRIM(product_id), '') IS NULL

   OR NULLIF(TRIM(store_id), '') IS NULL

   OR TRY_TO_NUMBER(
        NULLIF(TRIM(quantity), '')
      ) IS NULL

   OR TRY_TO_NUMBER(
        NULLIF(TRIM(quantity), '')
      ) <= 0

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

   OR TRY_TO_NUMBER(
        NULLIF(TRIM(discount_amount), ''),
        12,
        2
      ) IS NULL

   OR TRY_TO_NUMBER(
        NULLIF(TRIM(discount_amount), ''),
        12,
        2
      ) < 0

   OR TRY_TO_NUMBER(
        NULLIF(TRIM(discount_amount), ''),
        12,
        2
      )
      >
      TRY_TO_NUMBER(
          NULLIF(TRIM(quantity), '')
      )
      *
      TRY_TO_NUMBER(
          NULLIF(TRIM(unit_price), ''),
          12,
          2
      )

   OR UPPER(TRIM(payment_method))
      NOT IN ('CASH', 'CARD', 'UPI', 'WALLET');