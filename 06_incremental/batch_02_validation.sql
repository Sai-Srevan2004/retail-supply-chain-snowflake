USE DATABASE RETAIL_SUPPLY_CHAIN;

SELECT _batch_id, 'CUSTOMERS' entity, COUNT(*) rows
FROM RAW.CUSTOMERS WHERE _batch_id='BATCH_02' GROUP BY _batch_id
UNION ALL SELECT _batch_id, 'PRODUCTS', COUNT(*) FROM RAW.PRODUCTS WHERE _batch_id='BATCH_02' GROUP BY _batch_id
UNION ALL SELECT _batch_id, 'SALES', COUNT(*) FROM RAW.SALES WHERE _batch_id='BATCH_02' GROUP BY _batch_id;

-- Late-arriving dimension resolution: same customer_key before and after real data.
SELECT customer_key, customer_id, customer_name, email, is_inferred,
       effective_start_date, effective_end_date, is_current
FROM GOLD.DIM_CUSTOMER
WHERE customer_id = 'C99999'
ORDER BY customer_key;

SELECT product_id, unit_price, updated_at
FROM GOLD.DIM_PRODUCT
WHERE product_id IN ('P00001','P00002')
ORDER BY product_id;

SELECT _batch_id, COUNT(*) fact_rows, SUM(net_amount) net_sales
FROM GOLD.FACT_SALES
WHERE _batch_id='BATCH_02'
GROUP BY _batch_id;
