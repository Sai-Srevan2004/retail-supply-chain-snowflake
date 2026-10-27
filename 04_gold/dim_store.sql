USE DATABASE RETAIL_SUPPLY_CHAIN;

CREATE TABLE IF NOT EXISTS GOLD.DIM_STORE (
  store_key NUMBER AUTOINCREMENT START 1 INCREMENT 1,
  store_id STRING NOT NULL,
  store_name STRING,
  city STRING,
  state STRING,
  region STRING,
  store_type STRING,
  opened_date DATE,
  is_inferred BOOLEAN NOT NULL DEFAULT FALSE,
  _source_file STRING,
  _batch_id STRING,
  _loaded_at TIMESTAMP_NTZ,
  CONSTRAINT PK_DIM_STORE PRIMARY KEY (store_key)
);

INSERT INTO GOLD.DIM_STORE
(store_id, store_name, city, state, region, store_type, opened_date,
 is_inferred, _source_file, _batch_id, _loaded_at)
SELECT store_id, store_name, city, state, region, store_type, opened_date,
       FALSE, _source_file, _batch_id, _loaded_at
FROM SILVER.STORES s
WHERE NOT EXISTS (SELECT 1 FROM GOLD.DIM_STORE t WHERE t.store_id = s.store_id);
