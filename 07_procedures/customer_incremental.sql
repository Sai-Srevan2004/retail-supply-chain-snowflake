USE DATABASE RETAIL_SUPPLY_CHAIN;

CREATE OR REPLACE PROCEDURE GOLD.PROCESS_CUSTOMER_INCREMENTAL()
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
  -- 1. CREATE TEMPORARY TABLES BEFORE TRANSACTION
  --
  -- IMPORTANT:
  -- Keep source values as VARCHAR here.
  -- This prevents bad timestamps from failing during stream capture.
  --------------------------------------------------------------------

  CREATE OR REPLACE TEMPORARY TABLE CUSTOMER_CHANGES
  (
    customer_id   VARCHAR,
    customer_name VARCHAR,
    email         VARCHAR,
    phone         VARCHAR,
    region        VARCHAR,
    segment       VARCHAR,
    created_at    VARCHAR,
    updated_at    VARCHAR,
    _source_file  VARCHAR,
    _batch_id     VARCHAR,
    _loaded_at    TIMESTAMP_NTZ,
    _row_number   NUMBER
  );


  CREATE OR REPLACE TEMPORARY TABLE TYPED_CUSTOMERS
  (
    customer_id   VARCHAR,
    customer_name VARCHAR,
    email         VARCHAR,
    phone         VARCHAR,
    region        VARCHAR,
    segment       VARCHAR,
    created_at    TIMESTAMP_NTZ,
    updated_at    TIMESTAMP_NTZ,
    _source_file  VARCHAR,
    _batch_id     VARCHAR,
    _loaded_at    TIMESTAMP_NTZ,
    _row_number   NUMBER
  );


  --------------------------------------------------------------------
  -- 2. START TRANSACTION
  --------------------------------------------------------------------

  BEGIN TRANSACTION;


  --------------------------------------------------------------------
  -- 3. READ CUSTOMER STREAM
  --
  -- Raw values are captured without forcing timestamp conversion.
  --------------------------------------------------------------------

  INSERT INTO CUSTOMER_CHANGES
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
    _loaded_at,
    _row_number
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
      _loaded_at,
      _row_number

  FROM RAW.CUSTOMER_STREAM

  WHERE METADATA$ACTION = 'INSERT';


  --------------------------------------------------------------------
  -- 4. BASIC COUNTS
  --------------------------------------------------------------------

  SELECT COUNT(*), MAX(_batch_id)
    INTO :V_RECORDS_READ, :V_BATCH_ID
  FROM CUSTOMER_CHANGES;


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
    'CUSTOMER',
    'PROCESS_CUSTOMER_INCREMENTAL',
    CURRENT_TIMESTAMP(),
    'RUNNING',
    :V_RECORDS_READ,
    0,
    0
  );


  --------------------------------------------------------------------
  -- 6. CONVERT RAW VALUES INTO PROPER DATA TYPES
  --
  -- TRY_TO_TIMESTAMP_NTZ() returns NULL for invalid timestamps.
  --
  -- Example:
  --
  -- '2026-09-31 10:00:00'
  --          ↓
  -- TRY_TO_TIMESTAMP_NTZ()
  --          ↓
  -- NULL
  --------------------------------------------------------------------

  INSERT INTO TYPED_CUSTOMERS
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
    _loaded_at,
    _row_number
  )

  SELECT
      NULLIF(TRIM(customer_id), '') AS customer_id,

      NULLIF(TRIM(customer_name), '') AS customer_name,

      LOWER(
        NULLIF(TRIM(email), '')
      ) AS email,

      NULLIF(TRIM(phone), '') AS phone,

      UPPER(
        NULLIF(TRIM(region), '')
      ) AS region,

      UPPER(
        NULLIF(TRIM(segment), '')
      ) AS segment,

      TRY_TO_TIMESTAMP_NTZ(
        NULLIF(TRIM(created_at), '')
      ) AS created_at,

      TRY_TO_TIMESTAMP_NTZ(
        NULLIF(TRIM(updated_at), '')
      ) AS updated_at,

      _source_file,
      _batch_id,
      _loaded_at,
      _row_number

  FROM CUSTOMER_CHANGES;


  --------------------------------------------------------------------
  -- 7. VALID CUSTOMER CHANGES
  --
  -- Deduplicate by customer_id.
  -- Latest updated_at wins.
  --------------------------------------------------------------------

  CREATE OR REPLACE TEMPORARY TABLE VALID_CUSTOMER_CHANGES AS

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
        t.*,

        ROW_NUMBER() OVER
        (
          PARTITION BY t.customer_id

          ORDER BY
            t.updated_at DESC NULLS LAST,
            t._row_number DESC
        ) AS rn

    FROM TYPED_CUSTOMERS t

    WHERE t.customer_id IS NOT NULL
  )

  WHERE rn = 1

    AND customer_id IS NOT NULL

    AND customer_name IS NOT NULL

    AND email IS NOT NULL

    AND REGEXP_LIKE(
          email,
          '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$'
        )

    AND created_at IS NOT NULL

    AND updated_at IS NOT NULL;


  --------------------------------------------------------------------
  -- 8. REJECT INVALID CUSTOMERS
  --
  -- IMPORTANT:
  -- This reads from TYPED_CUSTOMERS.
  --
  -- Therefore invalid timestamps have already become NULL.
  --------------------------------------------------------------------

  INSERT INTO SILVER.REJECTED_RECORDS

  SELECT
      c._source_file,

      'CUSTOMER',

      c.customer_id,

      CASE

        WHEN c.customer_id IS NULL
          THEN 'MISSING_CUSTOMER_ID'

        WHEN c.customer_name IS NULL
          THEN 'MISSING_CUSTOMER_NAME'

        WHEN c.email IS NULL
             OR NOT REGEXP_LIKE(
                  c.email,
                  '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$'
                )
          THEN 'INVALID_EMAIL'

        WHEN c.created_at IS NULL
          OR c.updated_at IS NULL
          THEN 'INVALID_TIMESTAMP'

        ELSE 'INVALID_CUSTOMER'

      END,

      OBJECT_CONSTRUCT_KEEP_NULL(
        'customer_id', c.customer_id,
        'customer_name', c.customer_name,
        'email', c.email,
        'phone', c.phone,
        'region', c.region,
        'segment', c.segment,
        'created_at', c.created_at,
        'updated_at', c.updated_at
      ),

      c._batch_id,

      CURRENT_TIMESTAMP()

  FROM TYPED_CUSTOMERS c

  WHERE
       c.customer_id IS NULL

    OR c.customer_name IS NULL

    OR c.email IS NULL

    OR NOT REGEXP_LIKE(
         c.email,
         '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$'
       )

    OR c.created_at IS NULL

    OR c.updated_at IS NULL

  AND NOT EXISTS
  (
    SELECT 1

    FROM SILVER.REJECTED_RECORDS r

    WHERE r.source_file = c._source_file

      AND r.entity_name = 'CUSTOMER'

      AND NVL(r.business_key, '') =
          NVL(c.customer_id, '')

      AND r.batch_id = c._batch_id
  );


  --------------------------------------------------------------------
  -- 9. CAPTURE REJECT COUNT
  --------------------------------------------------------------------

  V_RECORDS_REJECTED := SQLROWCOUNT;


  --------------------------------------------------------------------
  -- 10. MERGE VALID CUSTOMERS INTO SILVER
  --------------------------------------------------------------------

  MERGE INTO SILVER.CUSTOMERS t

  USING VALID_CUSTOMER_CHANGES s

    ON t.customer_id = s.customer_id

  WHEN MATCHED THEN

    UPDATE SET
      customer_name = s.customer_name,
      email = s.email,
      phone = s.phone,
      region = s.region,
      segment = s.segment,
      created_at = s.created_at,
      updated_at = s.updated_at,
      _source_file = s._source_file,
      _batch_id = s._batch_id,
      _loaded_at = s._loaded_at

  WHEN NOT MATCHED THEN

    INSERT
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

    VALUES
    (
      s.customer_id,
      s.customer_name,
      s.email,
      s.phone,
      s.region,
      s.segment,
      s.created_at,
      s.updated_at,
      s._source_file,
      s._batch_id,
      s._loaded_at
    );


  --------------------------------------------------------------------
  -- 11. RESOLVE LATE-ARRIVING / INFERRED CUSTOMER
  --
  -- Keep the existing customer_key.
  --------------------------------------------------------------------

  UPDATE GOLD.DIM_CUSTOMER c

  SET
      customer_name = v.customer_name,
      email = v.email,
      phone = v.phone,
      region = v.region,
      segment = v.segment,

      is_inferred = FALSE,

      _source_file = v._source_file,
      _batch_id = v._batch_id,
      _loaded_at = v._loaded_at

  FROM VALID_CUSTOMER_CHANGES v

  WHERE c.customer_id = v.customer_id

    AND c.is_current = TRUE

    AND c.is_inferred = TRUE;


  --------------------------------------------------------------------
  -- 12. EXPIRE CURRENT SCD2 VERSION WHEN ATTRIBUTES CHANGE
  --------------------------------------------------------------------

  UPDATE GOLD.DIM_CUSTOMER c

  SET
      effective_end_date = v.updated_at,

      is_current = FALSE,

      _loaded_at = CURRENT_TIMESTAMP()

  FROM VALID_CUSTOMER_CHANGES v

  WHERE c.customer_id = v.customer_id

    AND c.is_current = TRUE

    AND c.is_inferred = FALSE

    AND
    (
         NVL(c.customer_name, '') <> NVL(v.customer_name, '')

      OR NVL(c.email, '') <> NVL(v.email, '')

      OR NVL(c.phone, '') <> NVL(v.phone, '')

      OR NVL(c.region, '') <> NVL(v.region, '')

      OR NVL(c.segment, '') <> NVL(v.segment, '')
    );


  --------------------------------------------------------------------
  -- 13. INSERT NEW SCD2 VERSION
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

  SELECT
      v.customer_id,
      v.customer_name,
      v.email,
      v.phone,
      v.region,
      v.segment,

      v.updated_at,

      '9999-12-31 23:59:59'::TIMESTAMP_NTZ,

      TRUE,

      FALSE,

      v._source_file,
      v._batch_id,
      v._loaded_at

  FROM VALID_CUSTOMER_CHANGES v

  LEFT JOIN GOLD.DIM_CUSTOMER c

    ON c.customer_id = v.customer_id

   AND c.is_current = TRUE

  WHERE c.customer_key IS NULL;


  --------------------------------------------------------------------
  -- 14. RECORD WRITTEN COUNT
  --------------------------------------------------------------------

  SELECT COUNT(*)
    INTO :V_RECORDS_WRITTEN

  FROM VALID_CUSTOMER_CHANGES;


  --------------------------------------------------------------------
  -- 15. UPDATE PIPELINE AUDIT
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
      'CUSTOMER_INCREMENTAL_COMPLETED: '
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
      'CUSTOMER',
      'PROCESS_CUSTOMER_INCREMENTAL',

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