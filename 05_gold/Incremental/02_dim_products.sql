USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA GOLD;


MERGE INTO GOLD.DIM_PRODUCT AS tgt
USING (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        p.brand,
        p.supplier_id,
        ds.supplier_key,
        p.unit_price,
        p.created_at,
        p.updated_at,
        p._source_file,
        p._batch_id,
        p._loaded_at
    FROM SILVER.PRODUCTS_STREAM p
    LEFT JOIN GOLD.DIM_SUPPLIER ds
        ON p.supplier_id = ds.supplier_id
    WHERE p.METADATA$ACTION = 'INSERT'
) AS src
ON tgt.product_id = src.product_id

WHEN MATCHED AND (src.updated_at > tgt.updated_at OR tgt.updated_at IS NULL)
THEN UPDATE SET
    product_name  = src.product_name,
    category      = src.category,
    brand         = src.brand,
    supplier_id   = src.supplier_id,
    supplier_key  = src.supplier_key,
    unit_price    = src.unit_price,
    created_at    = src.created_at,
    updated_at    = src.updated_at,
    _source_file  = src._source_file,
    _batch_id     = src._batch_id,
    _loaded_at    = src._loaded_at

WHEN NOT MATCHED THEN INSERT (
    product_id, product_name, category, brand,
    supplier_id, supplier_key, unit_price,
    created_at, updated_at,
    _source_file, _batch_id, _loaded_at
) VALUES (
    src.product_id, src.product_name, src.category, src.brand,
    src.supplier_id, src.supplier_key, src.unit_price,
    src.created_at, src.updated_at,
    src._source_file, src._batch_id, src._loaded_at
);
