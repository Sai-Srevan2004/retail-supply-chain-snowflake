USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


-- ============================================================
-- SILVER VALIDATION SUMMARY
-- ============================================================

SELECT
    'CUSTOMERS' AS ENTITY,

    (SELECT COUNT(*)
     FROM RAW.CUSTOMERS) AS RAW_COUNT,

    (SELECT COUNT(*)
     FROM SILVER.CUSTOMERS) AS SILVER_COUNT,

    (SELECT COUNT(*)
     FROM SILVER.REJECTED_RECORDS
     WHERE entity_name = 'CUSTOMER'
       AND batch_id = 'INITIAL') AS REJECTED_COUNT

UNION ALL

SELECT
    'PRODUCTS',

    (SELECT COUNT(*)
     FROM RAW.PRODUCTS),

    (SELECT COUNT(*)
     FROM SILVER.PRODUCTS),

    (SELECT COUNT(*)
     FROM SILVER.REJECTED_RECORDS
     WHERE entity_name = 'PRODUCT'
       AND batch_id = 'INITIAL')

UNION ALL

SELECT
    'SUPPLIERS',

    (SELECT COUNT(*)
     FROM RAW.SUPPLIERS),

    (SELECT COUNT(*)
     FROM SILVER.SUPPLIERS),

    (SELECT COUNT(*)
     FROM SILVER.REJECTED_RECORDS
     WHERE entity_name = 'SUPPLIER'
       AND batch_id = 'INITIAL')

UNION ALL

SELECT
    'STORES',

    (SELECT COUNT(*)
     FROM RAW.STORES),

    (SELECT COUNT(*)
     FROM SILVER.STORES),

    (SELECT COUNT(*)
     FROM SILVER.REJECTED_RECORDS
     WHERE entity_name = 'STORE'
       AND batch_id = 'INITIAL')

UNION ALL

SELECT
    'SALES',

    (SELECT COUNT(*)
     FROM RAW.SALES),

    (SELECT COUNT(*)
     FROM SILVER.SALES),

    (SELECT COUNT(*)
     FROM SILVER.REJECTED_RECORDS
     WHERE entity_name = 'SALE'
       AND batch_id = 'INITIAL');


-- ============================================================
-- 8. REJECTION REASON SUMMARY
-- ============================================================

SELECT
    entity_name,
    rejection_reason,
    COUNT(*) AS rejected_records
FROM SILVER.REJECTED_RECORDS
WHERE batch_id = 'INITIAL'
GROUP BY
    entity_name,
    rejection_reason
ORDER BY
    entity_name,
    rejected_records DESC;


-- ============================================================
-- 9. REFERENTIAL INTEGRITY CHECKS
-- ============================================================

-- Sales → Customers
SELECT COUNT(*) AS orphan_customer_sales
FROM SILVER.SALES s
LEFT JOIN SILVER.CUSTOMERS c
    ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- Sales → Products
SELECT COUNT(*) AS orphan_product_sales
FROM SILVER.SALES s
LEFT JOIN SILVER.PRODUCTS p
    ON s.product_id = p.product_id
WHERE p.product_id IS NULL;


-- Sales → Stores
SELECT COUNT(*) AS orphan_store_sales
FROM SILVER.SALES s
LEFT JOIN SILVER.STORES st
    ON s.store_id = st.store_id
WHERE st.store_id IS NULL;


-- Products → Suppliers
SELECT COUNT(*) AS orphan_product_suppliers
FROM SILVER.PRODUCTS p
LEFT JOIN SILVER.SUPPLIERS s
    ON p.supplier_id = s.supplier_id
WHERE s.supplier_id IS NULL;


-- ============================================================
-- 10. DUPLICATE CHECKS
-- ============================================================

SELECT
    'CUSTOMERS' AS ENTITY,
    COUNT(*) AS DUPLICATE_KEYS
FROM (
    SELECT customer_id
    FROM SILVER.CUSTOMERS
    GROUP BY customer_id
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'PRODUCTS',
    COUNT(*)
FROM (
    SELECT product_id
    FROM SILVER.PRODUCTS
    GROUP BY product_id
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'SUPPLIERS',
    COUNT(*)
FROM (
    SELECT supplier_id
    FROM SILVER.SUPPLIERS
    GROUP BY supplier_id
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'STORES',
    COUNT(*)
FROM (
    SELECT store_id
    FROM SILVER.STORES
    GROUP BY store_id
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'SALES',
    COUNT(*)
FROM (
    SELECT sale_id
    FROM SILVER.SALES
    GROUP BY sale_id
    HAVING COUNT(*) > 1
);


-- ============================================================
-- 11. FINAL SILVER ROW COUNTS
-- ============================================================

SELECT 'CUSTOMERS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT
FROM SILVER.CUSTOMERS

UNION ALL

SELECT 'PRODUCTS', COUNT(*)
FROM SILVER.PRODUCTS

UNION ALL

SELECT 'SUPPLIERS', COUNT(*)
FROM SILVER.SUPPLIERS

UNION ALL

SELECT 'STORES', COUNT(*)
FROM SILVER.STORES

UNION ALL

SELECT 'SALES', COUNT(*)
FROM SILVER.SALES;