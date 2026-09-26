USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE RAW.CUSTOMERS (
    customer_id      VARCHAR,
    customer_name    VARCHAR,
    email            VARCHAR,
    phone            VARCHAR,
    region           VARCHAR,
    segment          VARCHAR,
    created_at       VARCHAR,
    updated_at       VARCHAR,

    _source_file     VARCHAR,
    _loaded_at       TIMESTAMP_NTZ,
    _batch_id        VARCHAR,
    _row_number      NUMBER
);


--insert the data

COPY INTO RAW.CUSTOMERS (
    customer_id,
    customer_name,
    email,
    phone,
    region,
    segment,
    created_at,
    updated_at,
    _source_file,
    _loaded_at,
    _batch_id,
    _row_number
)
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
        'INITIAL',
        METADATA$FILE_ROW_NUMBER
    FROM @RAW.RETAIL_SOURCE_STAGE/initial/customers_initial.csv
)
FILE_FORMAT = (FORMAT_NAME = RAW.CSV_FORMAT)
ON_ERROR = 'ABORT_STATEMENT';