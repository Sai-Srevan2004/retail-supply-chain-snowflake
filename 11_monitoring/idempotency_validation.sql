USE DATABASE RETAIL_SUPPLY_CHAIN;

-- 1. No duplicate business keys in Silver customers.
SELECT customer_id, COUNT(*) row_count
FROM SILVER.CUSTOMERS
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 2. No duplicate sale IDs in Silver.
SELECT sale_id, COUNT(*) row_count
FROM SILVER.SALES
GROUP BY sale_id
HAVING COUNT(*) > 1;

-- 3. No duplicate sale IDs in Gold fact.
SELECT sale_id, COUNT(*) row_count
FROM GOLD.FACT_SALES
GROUP BY sale_id
HAVING COUNT(*) > 1;

-- 4. SCD2 must have at most one current row per customer.
SELECT customer_id, COUNT_IF(is_current) current_rows
FROM GOLD.DIM_CUSTOMER
GROUP BY customer_id
HAVING COUNT_IF(is_current) > 1;

-- 5. A rerun of the same batch must not increase the fact row count.
-- Record the count before/after rerunning the relevant batch and compare.
SELECT COUNT(*) AS fact_sales_count
FROM GOLD.FACT_SALES;

-- 6. Inferred customers must resolve in-place: same customer_key,
-- current row becomes non-inferred.
SELECT customer_id, customer_key, is_current, is_inferred,
       effective_start_date, effective_end_date
FROM GOLD.DIM_CUSTOMER
WHERE customer_id IN ('C99999')
ORDER BY customer_id, effective_start_date;

-- 7. Inspect duplicate/rejected records without creating duplicate quarantine rows.
SELECT source_file, entity_name, business_key, batch_id, rejection_reason,
       COUNT(*) AS quarantine_rows
FROM SILVER.REJECTED_RECORDS
GROUP BY source_file, entity_name, business_key, batch_id, rejection_reason
HAVING COUNT(*) > 1;
