USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA RAW;


-- =========================================================
-- RAW.CUSTOMERS
-- =========================================================

CREATE TABLE IF NOT EXISTS CUSTOMERS (

    customer_id     VARCHAR,
    customer_name   VARCHAR,
    email           VARCHAR,
    phone           VARCHAR,
    region          VARCHAR,
    segment         VARCHAR,
    created_at      VARCHAR,
    updated_at      VARCHAR,

    _source_file    VARCHAR,
    _loaded_at      TIMESTAMP_NTZ,
    _batch_id       VARCHAR,
    _row_number     NUMBER
);


-- =========================================================
-- RAW.PRODUCTS
-- =========================================================

CREATE TABLE IF NOT EXISTS PRODUCTS (

    product_id      VARCHAR,
    product_name    VARCHAR,
    category        VARCHAR,
    brand           VARCHAR,
    unit_price      VARCHAR,
    created_at      VARCHAR,
    updated_at      VARCHAR,
    is_active       VARCHAR,

    _source_file    VARCHAR,
    _loaded_at      TIMESTAMP_NTZ,
    _batch_id       VARCHAR,
    _row_number     NUMBER
);


-- =========================================================
-- RAW.STORES
-- =========================================================

CREATE TABLE IF NOT EXISTS STORES (

    store_id        VARCHAR,
    store_name      VARCHAR,
    city            VARCHAR,
    state           VARCHAR,
    region          VARCHAR,
    store_type      VARCHAR,
    opened_date     VARCHAR,

    _source_file    VARCHAR,
    _loaded_at      TIMESTAMP_NTZ,
    _batch_id       VARCHAR,
    _row_number     NUMBER
);


-- =========================================================
-- RAW.SALES
-- =========================================================

CREATE TABLE IF NOT EXISTS SALES (

    sale_id          VARCHAR,
    sale_timestamp   VARCHAR,
    customer_id      VARCHAR,
    product_id       VARCHAR,
    store_id         VARCHAR,
    quantity         VARCHAR,
    unit_price       VARCHAR,
    discount_amount  VARCHAR,
    payment_method   VARCHAR,

    _source_file     VARCHAR,
    _loaded_at       TIMESTAMP_NTZ,
    _batch_id        VARCHAR,
    _row_number      NUMBER
);