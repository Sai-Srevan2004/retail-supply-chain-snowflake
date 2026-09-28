USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA RAW;


COPY INTO RAW.PRODUCTS
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
        METADATA$FILENAME,
        CURRENT_TIMESTAMP(),
        'BATCH_02',
        METADATA$FILE_ROW_NUMBER
    FROM @RAW.RETAIL_SOURCE_STAGE/incremental/batch2/products_batch_02.csv
)
FILE_FORMAT = RAW.CSV_FORMAT
ON_ERROR = 'ABORT_STATEMENT';