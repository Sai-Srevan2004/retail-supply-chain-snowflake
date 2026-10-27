USE DATABASE RETAIL_SUPPLY_CHAIN;

-- 1. Expected initial + incremental counts (adjust after rejects/duplicates).
SELECT 'RAW_CUSTOMERS' check_name, COUNT(*) value FROM RAW.CUSTOMERS
UNION ALL SELECT 'RAW_PRODUCTS', COUNT(*) FROM RAW.PRODUCTS
UNION ALL SELECT 'RAW_STORES', COUNT(*) FROM RAW.STORES
UNION ALL SELECT 'RAW_SALES', COUNT(*) FROM RAW.SALES
UNION ALL SELECT 'SILVER_CUSTOMERS', COUNT(*) FROM SILVER.CUSTOMERS
UNION ALL SELECT 'SILVER_PRODUCTS', COUNT(*) FROM SILVER.PRODUCTS
UNION ALL SELECT 'SILVER_STORES', COUNT(*) FROM SILVER.STORES
UNION ALL SELECT 'SILVER_SALES', COUNT(*) FROM SILVER.SALES
UNION ALL SELECT 'REJECTED_RECORDS', COUNT(*) FROM SILVER.REJECTED_RECORDS
UNION ALL SELECT 'DIM_CUSTOMER', COUNT(*) FROM GOLD.DIM_CUSTOMER
UNION ALL SELECT 'DIM_PRODUCT', COUNT(*) FROM GOLD.DIM_PRODUCT
UNION ALL SELECT 'DIM_STORE', COUNT(*) FROM GOLD.DIM_STORE
UNION ALL SELECT 'FACT_SALES', COUNT(*) FROM GOLD.FACT_SALES;

-- 2. SCD2 invariant.
SELECT customer_id
FROM GOLD.DIM_CUSTOMER
GROUP BY customer_id
HAVING COUNT_IF(is_current) > 1;

-- 3. Late-arriving dimension invariant.
SELECT customer_id, MIN(customer_key) customer_key, COUNT(*) rows,
       COUNT_IF(is_inferred) inferred_rows
FROM GOLD.DIM_CUSTOMER
WHERE customer_id = 'C99999'
GROUP BY customer_id;

-- After Batch 02, expected: one row for C99999, inferred_rows = 0,
-- and the customer_key is the same key that was used by the Batch 01 fact.

-- 4. Fact foreign-key coverage.
SELECT COUNT(*) orphan_customer_facts
FROM GOLD.FACT_SALES f
LEFT JOIN GOLD.DIM_CUSTOMER c ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;

SELECT COUNT(*) orphan_product_facts
FROM GOLD.FACT_SALES f
LEFT JOIN GOLD.DIM_PRODUCT p ON f.product_key = p.product_key
WHERE p.product_key IS NULL;

SELECT COUNT(*) orphan_store_facts
FROM GOLD.FACT_SALES f
LEFT JOIN GOLD.DIM_STORE s ON f.store_key = s.store_key
WHERE s.store_key IS NULL;

-- 5. Business-key uniqueness in Silver.
SELECT customer_id, COUNT(*) c FROM SILVER.CUSTOMERS GROUP BY customer_id HAVING COUNT(*) > 1;
SELECT product_id, COUNT(*) c FROM SILVER.PRODUCTS GROUP BY product_id HAVING COUNT(*) > 1;
SELECT store_id, COUNT(*) c FROM SILVER.STORES GROUP BY store_id HAVING COUNT(*) > 1;
SELECT sale_id, COUNT(*) c FROM SILVER.SALES GROUP BY sale_id HAVING COUNT(*) > 1;
