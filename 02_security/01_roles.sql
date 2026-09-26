-- ============================================================
-- RETAIL SUPPLY CHAIN
-- RBAC
-- ============================================================
USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;

-- ------------------------------------------------------------
-- 1. CREATE ROLES
-- ------------------------------------------------------------

CREATE ROLE IF NOT EXISTS DATA_ENGINEER;

CREATE ROLE IF NOT EXISTS DATA_ANALYST;

CREATE ROLE IF NOT EXISTS DATA_VIEWER;

-- ------------------------------------------------------------
-- 2. ROLE HIERARCHY
-- ------------------------------------------------------------

GRANT ROLE DATA_VIEWER
    TO ROLE DATA_ANALYST;

GRANT ROLE DATA_ANALYST
    TO ROLE DATA_ENGINEER;