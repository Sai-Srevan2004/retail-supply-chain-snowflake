SELECT 'CUSTOMERS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT
FROM RAW.CUSTOMERS

UNION ALL

SELECT 'PRODUCTS', COUNT(*)
FROM RAW.PRODUCTS

UNION ALL

SELECT 'SUPPLIERS', COUNT(*)
FROM RAW.SUPPLIERS

UNION ALL

SELECT 'STORES', COUNT(*)
FROM RAW.STORES

UNION ALL

SELECT 'SALES', COUNT(*)
FROM RAW.SALES;



--verify source metadata
--------------------------

SELECT
    _source_file,
    _batch_id,
    COUNT(*) AS row_count
FROM RAW.CUSTOMERS
GROUP BY
    _source_file,
    _batch_id;

--verify all the records including duplicates are preserved in raw table
-----------------------------------------------------------------------

SELECT
    TRIM(customer_id) AS customer_id,
    COUNT(*) AS record_count
FROM RAW.CUSTOMERS
GROUP BY TRIM(customer_id)
HAVING COUNT(*) > 1
ORDER BY record_count DESC;

SELECT
    TRIM(sale_id) AS sale_id,
    COUNT(*) AS record_count
FROM RAW.SALES
GROUP BY TRIM(sale_id)
HAVING COUNT(*) > 1
ORDER BY record_count DESC;