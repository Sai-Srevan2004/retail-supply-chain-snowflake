USE DATABASE RETAIL_SUPPLY_CHAIN;

CREATE TABLE IF NOT EXISTS GOLD.DIM_DATE (
  date_key NUMBER NOT NULL,
  full_date DATE NOT NULL,
  day NUMBER,
  month NUMBER,
  month_name STRING,
  quarter NUMBER,
  year NUMBER,
  week NUMBER,
  day_of_week NUMBER,
  day_name STRING,
  is_weekend BOOLEAN,
  CONSTRAINT PK_DIM_DATE PRIMARY KEY (date_key)
);

INSERT INTO GOLD.DIM_DATE
SELECT TO_NUMBER(TO_CHAR(full_date, 'YYYYMMDD')) AS date_key,
       full_date,
       DAY(full_date),
       MONTH(full_date),
       MONTHNAME(full_date),
       QUARTER(full_date),
       YEAR(full_date),
       WEEKOFYEAR(full_date),
       DAYOFWEEKISO(full_date),
       DAYNAME(full_date),
       DAYOFWEEKISO(full_date) IN (6,7)
FROM (
  SELECT DATEADD(day, SEQ4(), '2025-01-01'::DATE) full_date
  FROM TABLE(GENERATOR(ROWCOUNT => 1095))
) d
WHERE NOT EXISTS (SELECT 1 FROM GOLD.DIM_DATE x WHERE x.date_key = TO_NUMBER(TO_CHAR(d.full_date, 'YYYYMMDD')));
