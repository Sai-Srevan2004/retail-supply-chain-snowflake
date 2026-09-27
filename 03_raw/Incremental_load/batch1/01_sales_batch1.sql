USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA RAW;


COPY INTO RAW.SALES
FROM (
    SELECT
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9,
        METADATA$FILENAME,
        CURRENT_TIMESTAMP(),
        'BATCH_01',
        METADATA$FILE_ROW_NUMBER
    FROM @RAW.RETAIL_SOURCE_STAGE/incremental/batch1/sales_batch_01.csv
)
FILE_FORMAT = RAW.CSV_FORMAT
ON_ERROR = 'ABORT_STATEMENT';