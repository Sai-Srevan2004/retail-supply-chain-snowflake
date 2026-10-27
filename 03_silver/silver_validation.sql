USE DATABASE RETAIL_SUPPLY_CHAIN;

-- Valid rows and business-key uniqueness.
SELECT 'CUSTOMERS' entity, COUNT(*) ,COUNT(DISTINCT customer_id) distinct_keys FROM SILVER.CUSTOMERS
UNION ALL SELECT 'PRODUCTS', COUNT(*), COUNT(DISTINCT product_id) FROM SILVER.PRODUCTS
UNION ALL SELECT 'STORES', COUNT(*), COUNT(DISTINCT store_id) FROM SILVER.STORES
UNION ALL SELECT 'SALES', COUNT(*), COUNT(DISTINCT sale_id) FROM SILVER.SALES;

SELECT entity_name, rejection_reason, COUNT(*) rejected_rows
FROM SILVER.REJECTED_RECORDS
GROUP BY entity_name, rejection_reason
ORDER BY entity_name, rejection_reason;

-- Duplicate diagnostics in RAW are separate from invalid diagnostics.
SELECT 'CUSTOMERS' entity, COUNT(*) - COUNT(DISTINCT customer_id) duplicate_rows FROM RAW.CUSTOMERS
UNION ALL SELECT 'PRODUCTS', COUNT(*) - COUNT(DISTINCT product_id) FROM RAW.PRODUCTS
UNION ALL SELECT 'STORES', COUNT(*) - COUNT(DISTINCT store_id) FROM RAW.STORES
UNION ALL SELECT 'SALES', COUNT(*) - COUNT(DISTINCT sale_id) FROM RAW.SALES;

-- Important: RAW arrivals do not have to equal SILVER + rejects because valid duplicates
-- can be removed during deduplication.
