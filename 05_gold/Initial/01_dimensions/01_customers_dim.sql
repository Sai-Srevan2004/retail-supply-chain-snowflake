USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA GOLD;

CREATE OR REPLACE TABLE GOLD.DIM_CUSTOMER (
    customer_key        NUMBER AUTOINCREMENT,
    customer_id         VARCHAR NOT NULL,

    customer_name       VARCHAR,
    email               VARCHAR,
    phone               VARCHAR,
    region              VARCHAR,
    segment              VARCHAR,

    effective_start_date TIMESTAMP_NTZ NOT NULL,
    effective_end_date   TIMESTAMP_NTZ,
    is_current           BOOLEAN NOT NULL,

    _source_file         VARCHAR,
    _batch_id            VARCHAR,
    _loaded_at           TIMESTAMP_NTZ,

    CONSTRAINT pk_dim_customer
        PRIMARY KEY (customer_key)
);


--load data
---------------

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
    customer_id,
    customer_name,
    email,
    phone,
    region,
    segment,

    COALESCE(
        updated_at,
        created_at,
        _loaded_at
    ) AS effective_start_date,

    '9999-12-31 23:59:59.000'::TIMESTAMP_NTZ AS effective_end_date,

    TRUE AS is_current,

    _source_file,
    _batch_id,
    _loaded_at
FROM SILVER.CUSTOMERS;

--validate row counts
-------------------------
SELECT
    customer_id,
    COUNT(*) AS current_count
FROM GOLD.DIM_CUSTOMER
WHERE is_current = TRUE
GROUP BY customer_id
HAVING COUNT(*) > 1;