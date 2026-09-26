-- ============================================================
-- CSV FILE FORMAT
-- ============================================================

USE DATABASE RETAIL_SUPPLY_CHAIN;

CREATE OR REPLACE FILE FORMAT RAW.CSV_FORMAT
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = FALSE
    EMPTY_FIELD_AS_NULL = TRUE
    NULL_IF = ('NULL', 'null', '');