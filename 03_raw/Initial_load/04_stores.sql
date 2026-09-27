USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE RAW.STORES (
    store_id         VARCHAR,
    store_name       VARCHAR,
    city             VARCHAR,
    state            VARCHAR,
    region           VARCHAR,
    store_type       VARCHAR,
    opened_date      VARCHAR,

    _source_file     VARCHAR,
    _loaded_at       TIMESTAMP_NTZ,
    _batch_id        VARCHAR,
    _row_number      NUMBER
);


--insert the data
---------------------

COPY INTO RAW.STORES (
    store_id,
    store_name,
    city,
    state,
    region,
    store_type,
    opened_date,
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
        METADATA$FILENAME,
        CURRENT_TIMESTAMP(),
        'INITIAL',
        METADATA$FILE_ROW_NUMBER
    FROM @RAW.RETAIL_SOURCE_STAGE/initial/stores_initial.csv
)
FILE_FORMAT = (FORMAT_NAME = RAW.CSV_FORMAT)
ON_ERROR = 'ABORT_STATEMENT';