USE DATABASE RETAIL_SUPPLY_CHAIN;

CREATE OR REPLACE PROCEDURE GOLD.PROCESS_SALES_INCREMENTAL()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  V_RUN_ID STRING DEFAULT UUID_STRING();
  V_BATCH_ID STRING DEFAULT NULL;
  V_RECORDS_READ NUMBER DEFAULT 0;
  V_RECORDS_REJECTED NUMBER DEFAULT 0;
  V_RECORDS_WRITTEN NUMBER DEFAULT 0;
  V_ERROR STRING DEFAULT NULL;

BEGIN

  --------------------------------------------------------------------
  -- 1. READ STREAM
  --------------------------------------------------------------------

  CREATE OR REPLACE TEMPORARY TABLE SALES_CHANGES AS
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
      _loaded_at,
      _batch_id,
      _row_number
  FROM RAW.SALES_STREAM
  WHERE METADATA$ACTION = 'INSERT';


  --------------------------------------------------------------------
  -- 2. BASIC COUNTS
  --------------------------------------------------------------------

  SELECT COUNT(*), MAX(_batch_id)
    INTO :V_RECORDS_READ, :V_BATCH_ID
  FROM SALES_CHANGES;


  --------------------------------------------------------------------
  -- 3. CONVERT RAW STRING VALUES INTO PROPER DATA TYPES
  --
  -- IMPORTANT:
  -- TRY_* returns NULL instead of throwing an error.
  --
  -- 'ABC' -> TRY_TO_DECIMAL() -> NULL
  --------------------------------------------------------------------

  CREATE OR REPLACE TEMPORARY TABLE TYPED_SALES AS
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

      TRY_TO_DECIMAL(
          NULLIF(TRIM(unit_price), ''),
          18,
          2
      ) AS unit_price,

      TRY_TO_DECIMAL(
          NULLIF(TRIM(discount_amount), ''),
          18,
          2
      ) AS discount_amount,

      UPPER(
          NULLIF(TRIM(payment_method), '')
      ) AS payment_method,

      _source_file,
      _loaded_at,
      _batch_id,
      _row_number

  FROM SALES_CHANGES;


  --------------------------------------------------------------------
  -- 4. START TRANSACTION
  --------------------------------------------------------------------

  BEGIN TRANSACTION;


  --------------------------------------------------------------------
  -- 5. PIPELINE RUN
  --------------------------------------------------------------------

  INSERT INTO CONTROL.PIPELINE_RUNS
    (
      run_id,
      batch_id,
      entity,
      process_name,
      started_at,
      status,
      records_read,
      records_rejected,
      records_written
    )
  VALUES
    (
      :V_RUN_ID,
      :V_BATCH_ID,
      'SALES',
      'PROCESS_SALES_INCREMENTAL',
      CURRENT_TIMESTAMP(),
      'RUNNING',
      :V_RECORDS_READ,
      0,
      0
    );


  --------------------------------------------------------------------
  -- 6. DUPLICATE SALES IN SAME BATCH
  --------------------------------------------------------------------

  INSERT INTO SILVER.REJECTED_RECORDS
  SELECT
      s._source_file,
      'SALE',
      s.sale_id,
      'DUPLICATE_SALE_IN_BATCH',

      OBJECT_CONSTRUCT_KEEP_NULL(
        'sale_id', s.sale_id,
        'sale_timestamp', s.sale_timestamp,
        'customer_id', s.customer_id,
        'product_id', s.product_id,
        'store_id', s.store_id,
        'quantity', s.quantity,
        'unit_price', s.unit_price,
        'discount_amount', s.discount_amount,
        'payment_method', s.payment_method
      ),

      s._batch_id,
      CURRENT_TIMESTAMP()

  FROM
  (
    SELECT
        t.*,

        ROW_NUMBER() OVER
        (
          PARTITION BY t.sale_id
          ORDER BY t._row_number DESC
        ) AS rn

    FROM TYPED_SALES t

    WHERE t.sale_id IS NOT NULL

  ) s

  WHERE s.rn > 1

    AND NOT EXISTS
    (
      SELECT 1
      FROM SILVER.REJECTED_RECORDS r

      WHERE r.source_file = s._source_file
        AND r.entity_name = 'SALE'
        AND NVL(r.business_key, '') = NVL(s.sale_id, '')
        AND r.batch_id = s._batch_id
        AND r.rejection_reason = 'DUPLICATE_SALE_IN_BATCH'
    );


  --------------------------------------------------------------------
  -- 7. VALID SALES
  --
  -- IMPORTANT:
  -- This uses TYPED_SALES, NOT SALES_CHANGES.
  --------------------------------------------------------------------

  CREATE OR REPLACE TEMPORARY TABLE VALID_SALES AS

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
      _loaded_at,
      _batch_id

  FROM
  (
    SELECT
        t.*,

        ROW_NUMBER() OVER
        (
          PARTITION BY t.sale_id
          ORDER BY t._row_number DESC
        ) AS rn

    FROM TYPED_SALES t

  ) x

  WHERE rn = 1

    AND sale_id IS NOT NULL

    AND sale_timestamp IS NOT NULL

    AND customer_id IS NOT NULL

    AND product_id IS NOT NULL

    AND store_id IS NOT NULL

    AND quantity IS NOT NULL
    AND quantity > 0

    AND unit_price IS NOT NULL
    AND unit_price > 0

    AND discount_amount IS NOT NULL
    AND discount_amount >= 0

    AND discount_amount <= quantity * unit_price

    AND payment_method IN
        (
          'CASH',
          'CARD',
          'UPI',
          'WALLET'
        );


  --------------------------------------------------------------------
  -- 8. REJECT INVALID SALES
  --
  -- IMPORTANT:
  -- Again we use TYPED_SALES.
  --
  -- Therefore:
  -- unit_price = 'ABC'
  --       ↓
  -- TRY_TO_DECIMAL()
  --       ↓
  -- NULL
  --       ↓
  -- INVALID_UNIT_PRICE
  --
  -- No numeric conversion error.
  --------------------------------------------------------------------

  INSERT INTO SILVER.REJECTED_RECORDS

  SELECT
      c._source_file,
      'SALE',
      c.sale_id,

      CASE

        WHEN c.sale_id IS NULL
          THEN 'MISSING_SALE_ID'

        WHEN c.sale_timestamp IS NULL
          THEN 'INVALID_TIMESTAMP'

        WHEN c.customer_id IS NULL
          THEN 'MISSING_CUSTOMER_ID'

        WHEN c.product_id IS NULL
          THEN 'MISSING_PRODUCT_ID'

        WHEN c.store_id IS NULL
          THEN 'MISSING_STORE_ID'

        WHEN c.quantity IS NULL
          THEN 'INVALID_QUANTITY'

        WHEN c.quantity <= 0
          THEN 'INVALID_QUANTITY'

        WHEN c.unit_price IS NULL
          THEN 'INVALID_UNIT_PRICE'

        WHEN c.unit_price <= 0
          THEN 'INVALID_UNIT_PRICE'

        WHEN c.discount_amount IS NULL
          THEN 'INVALID_DISCOUNT'

        WHEN c.discount_amount < 0
          THEN 'INVALID_DISCOUNT'

        WHEN c.discount_amount >
             c.quantity * c.unit_price
          THEN 'INVALID_DISCOUNT'

        WHEN c.payment_method IS NULL
          THEN 'INVALID_PAYMENT_METHOD'

        WHEN c.payment_method NOT IN
             (
               'CASH',
               'CARD',
               'UPI',
               'WALLET'
             )
          THEN 'INVALID_PAYMENT_METHOD'

        ELSE 'INVALID_SALE'

      END,

      OBJECT_CONSTRUCT_KEEP_NULL(
        'sale_id', c.sale_id,
        'sale_timestamp', c.sale_timestamp,
        'customer_id', c.customer_id,
        'product_id', c.product_id,
        'store_id', c.store_id,
        'quantity', c.quantity,
        'unit_price', c.unit_price,
        'discount_amount', c.discount_amount,
        'payment_method', c.payment_method
      ),

      c._batch_id,
      CURRENT_TIMESTAMP()

  FROM TYPED_SALES c

  WHERE

       c.sale_id IS NULL

    OR c.sale_timestamp IS NULL

    OR c.customer_id IS NULL

    OR c.product_id IS NULL

    OR c.store_id IS NULL

    OR c.quantity IS NULL
    OR c.quantity <= 0

    OR c.unit_price IS NULL
    OR c.unit_price <= 0

    OR c.discount_amount IS NULL
    OR c.discount_amount < 0

    OR c.discount_amount >
       c.quantity * c.unit_price

    OR c.payment_method IS NULL

    OR c.payment_method NOT IN
       (
         'CASH',
         'CARD',
         'UPI',
         'WALLET'
       )

  AND NOT EXISTS
  (
    SELECT 1
    FROM SILVER.REJECTED_RECORDS r

    WHERE r.source_file = c._source_file
      AND r.entity_name = 'SALE'
      AND NVL(r.business_key, '') = NVL(c.sale_id, '')
      AND r.batch_id = c._batch_id
  );


  --------------------------------------------------------------------
  -- 9. ONLY NEW VALID SALES
  --------------------------------------------------------------------

  CREATE OR REPLACE TEMPORARY TABLE NEW_VALID_SALES AS

  SELECT v.*

  FROM VALID_SALES v

  WHERE NOT EXISTS
  (
    SELECT 1
    FROM SILVER.SALES s
    WHERE s.sale_id = v.sale_id
  )

  AND NOT EXISTS
  (
    SELECT 1
    FROM GOLD.FACT_SALES f
    WHERE f.sale_id = v.sale_id
  );


  --------------------------------------------------------------------
  -- 10. LATE-ARRIVING CUSTOMER
  --------------------------------------------------------------------

  INSERT INTO GOLD.DIM_CUSTOMER
  (
    customer_id,
    customer_name,
    email,
    phone,
    region,
    segment,
    effective_start_date,
    effective_end_date,
    is_current,
    is_inferred,
    _source_file,
    _batch_id,
    _loaded_at
  )

  SELECT DISTINCT
      s.customer_id,

      'UNKNOWN',
      NULL,
      NULL,
      'UNKNOWN',
      'UNKNOWN',

      '1900-01-01 00:00:00'::TIMESTAMP_NTZ,

      '9999-12-31 23:59:59'::TIMESTAMP_NTZ,

      TRUE,
      TRUE,

      s._source_file,
      s._batch_id,
      s._loaded_at

  FROM NEW_VALID_SALES s

  WHERE NOT EXISTS
  (
    SELECT 1
    FROM GOLD.DIM_CUSTOMER c

    WHERE c.customer_id = s.customer_id
  );


  --------------------------------------------------------------------
  -- 11. LATE-ARRIVING PRODUCT
  --------------------------------------------------------------------

  INSERT INTO GOLD.DIM_PRODUCT
  (
    product_id,
    product_name,
    category,
    brand,
    unit_price,
    is_active,
    is_inferred,
    _source_file,
    _batch_id,
    _loaded_at
  )

  SELECT
      s.product_id,

      'UNKNOWN',
      'UNKNOWN',
      'UNKNOWN',
      NULL,

      TRUE,
      TRUE,

      MIN(s._source_file),
      MIN(s._batch_id),
      MIN(s._loaded_at)

  FROM NEW_VALID_SALES s

  WHERE NOT EXISTS
  (
    SELECT 1
    FROM GOLD.DIM_PRODUCT p

    WHERE p.product_id = s.product_id
  )

  GROUP BY s.product_id;


  --------------------------------------------------------------------
  -- 12. INSERT INTO SILVER.SALES
  --------------------------------------------------------------------

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

  FROM NEW_VALID_SALES;


  --------------------------------------------------------------------
  -- 13. INSERT INTO GOLD.FACT_SALES
  --------------------------------------------------------------------

  INSERT INTO GOLD.FACT_SALES
  (
    sale_id,
    date_key,
    customer_key,
    product_key,
    store_key,
    sale_timestamp,
    quantity,
    unit_price,
    discount,
    gross_amount,
    discount_amount,
    net_amount,
    payment_method,
    _source_file,
    _batch_id,
    _loaded_at
  )

  SELECT
      s.sale_id,

      TO_NUMBER(
        TO_CHAR(
          s.sale_timestamp::DATE,
          'YYYYMMDD'
        )
      ),

      c.customer_key,

      p.product_key,

      st.store_key,

      s.sale_timestamp,

      s.quantity,

      s.unit_price,

      s.discount_amount,

      s.quantity * s.unit_price,

      s.discount_amount,

      (s.quantity * s.unit_price)
        - s.discount_amount,

      s.payment_method,

      s._source_file,
      s._batch_id,
      s._loaded_at

  FROM NEW_VALID_SALES s

  JOIN GOLD.DIM_CUSTOMER c
    ON c.customer_id = s.customer_id

   AND c.effective_start_date <= s.sale_timestamp

   AND s.sale_timestamp < c.effective_end_date

  JOIN GOLD.DIM_PRODUCT p
    ON p.product_id = s.product_id

  JOIN GOLD.DIM_STORE st
    ON st.store_id = s.store_id;


  --------------------------------------------------------------------
  -- 14. RECORD COUNTS
  --------------------------------------------------------------------

  SELECT COUNT(*)
  INTO :V_RECORDS_REJECTED

  FROM SILVER.REJECTED_RECORDS r

  WHERE r.batch_id = :V_BATCH_ID
    AND r.entity_name = 'SALE';


  SELECT COUNT(*)
  INTO :V_RECORDS_WRITTEN

  FROM NEW_VALID_SALES;


  --------------------------------------------------------------------
  -- 15. UPDATE PIPELINE RUN
  --------------------------------------------------------------------

  UPDATE CONTROL.PIPELINE_RUNS

  SET
      completed_at = CURRENT_TIMESTAMP(),
      status = 'SUCCESS',
      records_rejected = :V_RECORDS_REJECTED,
      records_written = :V_RECORDS_WRITTEN

  WHERE run_id = :V_RUN_ID;


  --------------------------------------------------------------------
  -- 16. COMMIT
  --------------------------------------------------------------------

  COMMIT;


  RETURN
      'SALES_INCREMENTAL_COMPLETED: '
      || V_RUN_ID
      || ' | READ='
      || V_RECORDS_READ
      || ' | REJECTED='
      || V_RECORDS_REJECTED
      || ' | WRITTEN='
      || V_RECORDS_WRITTEN;


EXCEPTION

  WHEN OTHER THEN

    V_ERROR := SQLCODE || ': ' || SQLERRM;

    ROLLBACK;

    INSERT INTO CONTROL.PIPELINE_RUNS
    (
      run_id,
      batch_id,
      entity,
      process_name,
      started_at,
      completed_at,
      status,
      records_read,
      records_rejected,
      records_written,
      error_message
    )

    VALUES
    (
      :V_RUN_ID,
      :V_BATCH_ID,
      'SALES',
      'PROCESS_SALES_INCREMENTAL',
      CURRENT_TIMESTAMP(),
      CURRENT_TIMESTAMP(),
      'FAILED',
      :V_RECORDS_READ,
      :V_RECORDS_REJECTED,
      0,
      :V_ERROR
    );

    RAISE;

END;
$$;