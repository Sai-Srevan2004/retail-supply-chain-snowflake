CREATE OR REPLACE TEMPORARY TABLE SILVER_STREAM_DATA_CUSTOMERS AS
SELECT customer_id, customer_name, email, phone, region, segment,
       created_at, updated_at, _source_file, _batch_id, _loaded_at
FROM SILVER.CUSTOMERS_STREAM
WHERE METADATA$ACTION = 'INSERT';


-- ------------------------------------------------------------
-- Step 1: expire current DIM_CUSTOMER rows whose tracked attributes
-- changed, comparing only against the rows Silver actually touched.
-- ------------------------------------------------------------
MERGE INTO GOLD.DIM_CUSTOMER AS tgt
USING SILVER_STREAM_DATA_CUSTOMERS AS src
ON tgt.customer_id = src.customer_id
   AND tgt.is_current = TRUE
WHEN MATCHED AND (
        NVL(tgt.customer_name, '') <> NVL(src.customer_name, '')
     OR NVL(tgt.email, '')         <> NVL(src.email, '')
     OR NVL(tgt.phone, '')         <> NVL(src.phone, '')
     OR NVL(tgt.region, '')        <> NVL(src.region, '')
     OR NVL(tgt.segment, '')       <> NVL(src.segment, '')
) THEN UPDATE SET
    is_current         = FALSE,
    effective_end_date = COALESCE(src.updated_at, src.created_at, src._loaded_at);


-- ------------------------------------------------------------
-- Step 2: insert a new current version for:
--   (a) customer_ids with no current dimension row at all (new), and
--   (b) customer_ids whose current row was just expired in step 1
--       (attributes changed).
-- Both cases collapse to the same condition: no existing row is both
-- current AND attribute-identical to the incoming source row.
-- ------------------------------------------------------------
INSERT INTO GOLD.DIM_CUSTOMER (
    customer_id,
    customer_name,
    email,
    phone,
    region,
    segment,
    effective_start_date,
    effective_end_date,
    is_current,
    _source_file,
    _batch_id,
    _loaded_at
)
SELECT
    src.customer_id,
    src.customer_name,
    src.email,
    src.phone,
    src.region,
    src.segment,
    COALESCE(src.updated_at, src.created_at, src._loaded_at) AS effective_start_date,
    '9999-12-31 23:59:59.000'::TIMESTAMP_NTZ AS effective_end_date,
    TRUE AS is_current,
    src._source_file,
    src._batch_id,
    src._loaded_at
FROM SILVER_STREAM_DATA_CUSTOMERS src
WHERE NOT EXISTS (
    SELECT 1
    FROM GOLD.DIM_CUSTOMER d
    WHERE d.customer_id = src.customer_id
      AND d.is_current = TRUE
      AND NVL(d.customer_name, '') = NVL(src.customer_name, '')
      AND NVL(d.email, '')         = NVL(src.email, '')
      AND NVL(d.phone, '')         = NVL(src.phone, '')
      AND NVL(d.region, '')        = NVL(src.region, '')
      AND NVL(d.segment, '')       = NVL(src.segment, '')
);
