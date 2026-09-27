USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA GOLD;


CREATE OR REPLACE TABLE GOLD.DIM_STORE (
    store_key       NUMBER AUTOINCREMENT,
    store_id        VARCHAR NOT NULL,

    store_name      VARCHAR,
    city            VARCHAR,
    state           VARCHAR,
    region          VARCHAR,
    store_type      VARCHAR,
    opened_date     DATE,

    _source_file    VARCHAR,
    _batch_id       VARCHAR,
    _loaded_at      TIMESTAMP_NTZ,

    CONSTRAINT pk_dim_store
        PRIMARY KEY (store_key)
);


INSERT INTO GOLD.DIM_STORE (
    store_id,
    store_name,
    city,
    state,
    region,
    store_type,
    opened_date,
    _source_file,
    _batch_id,
    _loaded_at
)
SELECT
    store_id,
    store_name,
    city,
    state,
    region,
    store_type,
    opened_date,
    _source_file,
    _batch_id,
    _loaded_at
FROM SILVER.STORES;