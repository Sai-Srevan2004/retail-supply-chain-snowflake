USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE RAW.SALES (
    sale_id          VARCHAR,
    customer_id      VARCHAR,
    product_id       VARCHAR,
    store_id         VARCHAR,
    sale_date        VARCHAR,
    quantity         VARCHAR,
    unit_price       VARCHAR,
    discount         VARCHAR,
    payment_method   VARCHAR,

    _source_file     VARCHAR,
    _loaded_at       TIMESTAMP_NTZ,
    _batch_id        VARCHAR,
    _row_number      NUMBER
);


--insert the data
------------------

COPY INTO RAW.SALES (
    sale_id,
    customer_id,
    product_id,
    store_id,
    sale_date,
    quantity,
    unit_price,
    discount,
    payment_method,
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
        $9,
        METADATA$FILENAME,
        CURRENT_TIMESTAMP(),
        'INITIAL',
        METADATA$FILE_ROW_NUMBER
    FROM @RAW.RETAIL_SOURCE_STAGE/initial/sales_initial.csv
)
FILE_FORMAT = (FORMAT_NAME = RAW.CSV_FORMAT)
ON_ERROR = 'ABORT_STATEMENT';