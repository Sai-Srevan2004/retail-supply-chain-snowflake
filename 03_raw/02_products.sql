USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE RAW.PRODUCTS (
    product_id       VARCHAR,
    product_name     VARCHAR,
    category         VARCHAR,
    brand            VARCHAR,
    supplier_id      VARCHAR,
    unit_price       VARCHAR,
    created_at       VARCHAR,
    updated_at       VARCHAR,

    _source_file     VARCHAR,
    _loaded_at       TIMESTAMP_NTZ,
    _batch_id        VARCHAR,
    _row_number      NUMBER
);

--insert the data
------------------

COPY INTO RAW.PRODUCTS (
    product_id,
    product_name,
    category,
    brand,
    supplier_id,
    unit_price,
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
    FROM @RAW.RETAIL_SOURCE_STAGE/initial/products_initial.csv
)
FILE_FORMAT = (FORMAT_NAME = RAW.CSV_FORMAT)
ON_ERROR = 'ABORT_STATEMENT';