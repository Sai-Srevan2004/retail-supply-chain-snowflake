USE DATABASE RETAIL_SUPPLY_CHAIN;

-- TARGET_LAG is a freshness target, not a guaranteed refresh interval.
CREATE OR REPLACE DYNAMIC TABLE GOLD.DAILY_SALES_SUMMARY
  TARGET_LAG = '5 minutes'
  WAREHOUSE = RETAIL_WH
  REFRESH_MODE = INCREMENTAL
AS
SELECT
  sale_timestamp::DATE AS sale_date,
  COUNT(DISTINCT sale_id) AS total_orders,
  SUM(quantity) AS total_quantity,
  SUM(gross_amount) AS gross_sales,
  SUM(discount_amount) AS discount_amount,
  SUM(net_amount) AS net_sales
FROM GOLD.FACT_SALES
GROUP BY sale_timestamp::DATE;

SHOW DYNAMIC TABLES LIKE 'DAILY_SALES_SUMMARY';
