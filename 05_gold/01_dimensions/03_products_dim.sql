USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA GOLD;

CREATE OR REPLACE TABLE GOLD.DIM_PRODUCT (
    product_key      NUMBER AUTOINCREMENT,
    product_id       VARCHAR NOT NULL,

    product_name     VARCHAR,
    category         VARCHAR,
    brand            VARCHAR,

    supplier_key     NUMBER,
    supplier_id      VARCHAR,

    unit_price       NUMBER(12,2),

    created_at       TIMESTAMP_NTZ,
    updated_at       TIMESTAMP_NTZ,

    _source_file     VARCHAR,
    _batch_id        VARCHAR,
    _loaded_at       TIMESTAMP_NTZ,

    CONSTRAINT pk_dim_product
        PRIMARY KEY (product_key)
);


--load data
------------

INSERT INTO GOLD.DIM_PRODUCT (
    product_id,
    product_name,
    category,
    brand,
    supplier_key,
    supplier_id,
    unit_price,
    created_at,
    updated_at,
    _source_file,
    _batch_id,
    _loaded_at
)
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.brand,

    s.supplier_key,
    p.supplier_id,

    p.unit_price,

    p.created_at,
    p.updated_at,

    p._source_file,
    p._batch_id,
    p._loaded_at

FROM SILVER.PRODUCTS p

LEFT JOIN GOLD.DIM_SUPPLIER s
    ON p.supplier_id = s.supplier_id;