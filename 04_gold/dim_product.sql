USE DATABASE RETAIL_SUPPLY_CHAIN;

CREATE TABLE IF NOT EXISTS GOLD.DIM_PRODUCT (
  product_key NUMBER AUTOINCREMENT START 1 INCREMENT 1,
  product_id STRING NOT NULL,
  product_name STRING,
  category STRING,
  brand STRING,
  unit_price NUMBER(12,2),
  created_at TIMESTAMP_NTZ,
  updated_at TIMESTAMP_NTZ,
  is_active BOOLEAN,
  is_inferred BOOLEAN NOT NULL DEFAULT FALSE,
  _source_file STRING,
  _batch_id STRING,
  _loaded_at TIMESTAMP_NTZ,
  CONSTRAINT PK_DIM_PRODUCT PRIMARY KEY (product_key)
);

INSERT INTO GOLD.DIM_PRODUCT
(product_id, product_name, category, brand, unit_price, created_at, updated_at,
 is_active, is_inferred, _source_file, _batch_id, _loaded_at)
SELECT product_id, product_name, category, brand, unit_price, created_at, updated_at,
       is_active, FALSE, _source_file, _batch_id, _loaded_at
FROM SILVER.PRODUCTS s
WHERE NOT EXISTS (SELECT 1 FROM GOLD.DIM_PRODUCT t WHERE t.product_id = s.product_id);
