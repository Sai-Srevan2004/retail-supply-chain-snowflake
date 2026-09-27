USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA GOLD;


CREATE OR REPLACE TABLE GOLD.DIM_DATE (
    date_key        NUMBER NOT NULL,
    full_date       DATE NOT NULL,

    day_of_week     NUMBER,
    day_name        VARCHAR,

    week_of_year    NUMBER,
    month_number    NUMBER,
    month_name      VARCHAR,

    quarter_number  NUMBER,
    quarter_name    VARCHAR,

    year_number     NUMBER,

    is_weekend      BOOLEAN,

    CONSTRAINT pk_dim_date
        PRIMARY KEY (date_key)
);

INSERT INTO GOLD.DIM_DATE (
    date_key,
    full_date,
    day_of_week,
    day_name,
    week_of_year,
    month_number,
    month_name,
    quarter_number,
    quarter_name,
    year_number,
    is_weekend
)
SELECT
    TO_NUMBER(TO_CHAR(full_date, 'YYYYMMDD')) AS date_key,

    full_date,

    DAYOFWEEK(full_date) AS day_of_week,

    DAYNAME(full_date) AS day_name,

    WEEKOFYEAR(full_date) AS week_of_year,

    MONTH(full_date) AS month_number,

    MONTHNAME(full_date) AS month_name,

    QUARTER(full_date) AS quarter_number,

    'Q' || QUARTER(full_date) AS quarter_name,

    YEAR(full_date) AS year_number,

    DAYOFWEEK(full_date) IN (1, 7) AS is_weekend

FROM (
    SELECT
        DATEADD(
            DAY,
            SEQ4(),
            '2025-01-01'::DATE
        ) AS full_date
    FROM TABLE(GENERATOR(ROWCOUNT => 1095))
);