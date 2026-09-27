USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA GOLD;

-- ============================================================
-- DIM_CUSTOMER - SCD2 INCREMENTAL LOAD
--
-- SILVER.CUSTOMERS stays Type-1 (clean, deduplicated, current state
-- only) - it does NOT need to change. History lives entirely here,
-- in GOLD.DIM_CUSTOMER. This script compares SILVER's current state
-- for each customer against the dimension's current row, and:
--   - leaves a customer alone if nothing tracked has changed
--   - expires the current row + inserts a new version if it has
--   - inserts a brand new row for a customer_id never seen before
--
-- Run this after every SILVER.CUSTOMERS refresh (i.e. after the
-- Silver customers pipeline finishes for a batch).
--
-- Uses your existing one-time load's effective_start_date convention
-- (COALESCE(updated_at, created_at, _loaded_at)) for consistency,
-- applied both when expiring the old version and starting the new one
-- so there's no gap/overlap between versions for the same customer.
-- ============================================================

-- ------------------------------------------------------------
-- Step 1: expire current rows whose tracked attributes changed.
-- Column-by-column comparison (NVL to treat NULL vs NULL as "same",
-- not as a mismatch) - fine at 5 tracked columns; a _row_hash column
-- would be worth adding only if this list grows much larger.
-- ------------------------------------------------------------
MERGE INTO GOLD.DIM_CUSTOMER AS tgt
USING SILVER.CUSTOMERS AS src
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
    NULL AS effective_end_date,
    TRUE AS is_current,
    src._source_file,
    src._batch_id,
    src._loaded_at
FROM SILVER.CUSTOMERS src
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


-- ------------------------------------------------------------
-- Sanity check (same one you already had): exactly one current row
-- per customer_id. Any result here means step 1/2 let something
-- through with two current versions - shouldn't happen, but worth
-- running after every load while this is new.
-- ------------------------------------------------------------
SELECT
    customer_id,
    COUNT(*) AS current_count
FROM GOLD.DIM_CUSTOMER
WHERE is_current = TRUE
GROUP BY customer_id
HAVING COUNT(*) > 1;