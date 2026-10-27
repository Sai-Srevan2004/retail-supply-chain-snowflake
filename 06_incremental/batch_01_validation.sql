USE DATABASE RETAIL_SUPPLY_CHAIN;

SELECT _batch_id, 'CUSTOMERS' entity, COUNT(*) rows
FROM RAW.CUSTOMERS WHERE _batch_id='BATCH_01' GROUP BY _batch_id
UNION ALL SELECT _batch_id, 'PRODUCTS', COUNT(*) FROM RAW.PRODUCTS WHERE _batch_id='BATCH_01' GROUP BY _batch_id
UNION ALL SELECT _batch_id, 'SALES', COUNT(*) FROM RAW.SALES WHERE _batch_id='BATCH_01' GROUP BY _batch_id;

-- SCD2 demonstration.
SELECT customer_key, customer_id, email, effective_start_date,
       effective_end_date, is_current, is_inferred
FROM GOLD.DIM_CUSTOMER
WHERE customer_id = 'C00001'
ORDER BY effective_start_date;

-- Late-arriving customer should be inferred after Batch 01 sales processing.
SELECT customer_key, customer_id, customer_name, is_inferred
FROM GOLD.DIM_CUSTOMER
WHERE customer_id = 'C99999';

-- Type 1 product should have the latest price only.
SELECT product_id, unit_price, updated_at
FROM GOLD.DIM_PRODUCT
WHERE product_id = 'P00001';

-- Batch 01 facts.
SELECT _batch_id, COUNT(*) fact_rows, SUM(net_amount) net_sales
FROM GOLD.FACT_SALES
WHERE _batch_id='BATCH_01'
GROUP BY _batch_id;
