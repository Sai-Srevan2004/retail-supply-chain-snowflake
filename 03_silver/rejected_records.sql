USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;

CREATE TABLE IF NOT EXISTS SILVER.REJECTED_RECORDS (
    source_file      STRING,
    entity_name      STRING,
    business_key     STRING,
    rejection_reason STRING,
    raw_record       VARIANT,
    batch_id         STRING,
    rejected_at      TIMESTAMP_NTZ
);