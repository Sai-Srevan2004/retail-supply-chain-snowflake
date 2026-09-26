-- ============================================================
-- INTERNAL SNOWFLAKE STAGE
-- ============================================================

USE DATABASE RETAIL_SUPPLY_CHAIN;

CREATE OR REPLACE STAGE RAW.RETAIL_SOURCE_STAGE
    FILE_FORMAT = RAW.CSV_FORMAT;


-- Verify stage
LIST @RAW.RETAIL_SOURCE_STAGE;