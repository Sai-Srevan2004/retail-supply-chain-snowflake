USE DATABASE RETAIL_SUPPLY_CHAIN;

CREATE TABLE IF NOT EXISTS GOLD.DIM_CUSTOMER (
  customer_key NUMBER AUTOINCREMENT START 1 INCREMENT 1,
  customer_id STRING NOT NULL,
  customer_name STRING,
  email STRING,
  phone STRING,
  region STRING,
  segment STRING,
  effective_start_date TIMESTAMP_NTZ NOT NULL,
  effective_end_date TIMESTAMP_NTZ NOT NULL,
  is_current BOOLEAN NOT NULL,
  is_inferred BOOLEAN NOT NULL DEFAULT FALSE,
  _source_file STRING,
  _batch_id STRING,
  _loaded_at TIMESTAMP_NTZ,
  CONSTRAINT PK_DIM_CUSTOMER PRIMARY KEY (customer_key)
);

-- Initial dimension: insert only customers that are not already present.
-- This makes the initial load safe to rerun.
MERGE INTO GOLD.DIM_CUSTOMER t
USING (
  SELECT customer_id, customer_name, email, phone, region, segment,
         COALESCE(created_at, '2026-01-01 00:00:00'::TIMESTAMP_NTZ) AS effective_start_date,
         '9999-12-31 23:59:59'::TIMESTAMP_NTZ AS effective_end_date,
         _source_file, _batch_id, _loaded_at
  FROM SILVER.CUSTOMERS
) s
ON t.customer_id = s.customer_id AND t.is_current = TRUE
WHEN NOT MATCHED THEN INSERT
(customer_id, customer_name, email, phone, region, segment,
 effective_start_date, effective_end_date, is_current, is_inferred,
 _source_file, _batch_id, _loaded_at)
VALUES
(s.customer_id, s.customer_name, s.email, s.phone, s.region, s.segment,
 s.effective_start_date, s.effective_end_date, TRUE, FALSE,
 s._source_file, s._batch_id, s._loaded_at);

-- SCD2 invariant: one current row per natural customer ID.
SELECT customer_id, COUNT_IF(is_current) current_rows
FROM GOLD.DIM_CUSTOMER
GROUP BY customer_id
HAVING COUNT_IF(is_current) > 1;
