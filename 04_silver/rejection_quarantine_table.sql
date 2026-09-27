USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


-- ============================================================
-- REJECTION / QUARANTINE TABLE
-- ============================================================

CREATE OR REPLACE TABLE SILVER.REJECTED_RECORDS (
    reject_id          NUMBER AUTOINCREMENT,
    source_file        VARCHAR,
    entity_name        VARCHAR,
    business_key       VARCHAR,
    rejection_reason   VARCHAR,
    raw_record         VARIANT,
    batch_id           VARCHAR,
    rejected_at        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);