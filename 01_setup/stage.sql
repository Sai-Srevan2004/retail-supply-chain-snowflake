USE DATABASE RETAIL_SUPPLY_CHAIN;

CREATE STAGE IF NOT EXISTS RAW.RETAIL_SOURCE_STAGE
  FILE_FORMAT = RAW.RETAIL_CSV_FORMAT;

-- Upload local files with SnowSQL/Snowflake CLI, for example:
-- PUT 'file:///absolute/path/data/customers_initial.csv'
--   @RAW.RETAIL_SOURCE_STAGE/initial AUTO_COMPRESS=TRUE;
--
-- Then verify:
LIST @RAW.RETAIL_SOURCE_STAGE;
