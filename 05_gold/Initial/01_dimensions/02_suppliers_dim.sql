USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA GOLD;

CREATE OR REPLACE TABLE GOLD.DIM_SUPPLIER (
    supplier_key     NUMBER AUTOINCREMENT,
    supplier_id      VARCHAR NOT NULL,

    supplier_name    VARCHAR,
    city             VARCHAR,
    state            VARCHAR,
    country          VARCHAR,
    contact_email    VARCHAR,

    updated_at       TIMESTAMP_NTZ,

    _source_file     VARCHAR,
    _batch_id        VARCHAR,
    _loaded_at       TIMESTAMP_NTZ,

    CONSTRAINT pk_dim_supplier
        PRIMARY KEY (supplier_key)
);


--load data
-------------

INSERT INTO GOLD.DIM_SUPPLIER (
    supplier_id,
    supplier_name,
    city,
    state,
    country,
    contact_email,
    updated_at,
    _source_file,
    _batch_id,
    _loaded_at
)
SELECT
    supplier_id,
    supplier_name,
    city,
    state,
    country,
    contact_email,
    updated_at,
    _source_file,
    _batch_id,
    _loaded_at
FROM SILVER.SUPPLIERS;