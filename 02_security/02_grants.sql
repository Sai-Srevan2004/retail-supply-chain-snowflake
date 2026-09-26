-- ============================================================
-- RETAIL SUPPLY CHAIN
-- ROLE & ACCESS CONFIGURATION
-- ============================================================

USE DATABASE RETAIL_SUPPLY_CHAIN;


-- ============================================================
-- 1. DATA ENGINEER
-- ============================================================

-- ------------------------------------------------------------
-- Database access
-- ------------------------------------------------------------

GRANT USAGE
ON DATABASE RETAIL_SUPPLY_CHAIN
TO ROLE DATA_ENGINEER;


-- ------------------------------------------------------------
-- Schema access
-- ------------------------------------------------------------

GRANT USAGE
ON SCHEMA RETAIL_SUPPLY_CHAIN.RAW
TO ROLE DATA_ENGINEER;

GRANT USAGE
ON SCHEMA RETAIL_SUPPLY_CHAIN.SILVER
TO ROLE DATA_ENGINEER;

GRANT USAGE
ON SCHEMA RETAIL_SUPPLY_CHAIN.GOLD
TO ROLE DATA_ENGINEER;

GRANT USAGE
ON SCHEMA RETAIL_SUPPLY_CHAIN.CONTROL
TO ROLE DATA_ENGINEER;


-- ------------------------------------------------------------
-- Table creation
-- ------------------------------------------------------------

GRANT CREATE TABLE
ON SCHEMA RETAIL_SUPPLY_CHAIN.RAW
TO ROLE DATA_ENGINEER;

GRANT CREATE TABLE
ON SCHEMA RETAIL_SUPPLY_CHAIN.SILVER
TO ROLE DATA_ENGINEER;

GRANT CREATE TABLE
ON SCHEMA RETAIL_SUPPLY_CHAIN.GOLD
TO ROLE DATA_ENGINEER;

GRANT CREATE TABLE
ON SCHEMA RETAIL_SUPPLY_CHAIN.CONTROL
TO ROLE DATA_ENGINEER;


-- ------------------------------------------------------------
-- Pipeline objects
-- ------------------------------------------------------------

GRANT CREATE STREAM
ON SCHEMA RETAIL_SUPPLY_CHAIN.RAW
TO ROLE DATA_ENGINEER;

GRANT CREATE TASK
ON SCHEMA RETAIL_SUPPLY_CHAIN.CONTROL
TO ROLE DATA_ENGINEER;

GRANT CREATE DYNAMIC TABLE
ON SCHEMA RETAIL_SUPPLY_CHAIN.GOLD
TO ROLE DATA_ENGINEER;


-- ------------------------------------------------------------
-- Source stage access
-- ------------------------------------------------------------

GRANT READ
ON STAGE RETAIL_SUPPLY_CHAIN.RAW.RETAIL_SOURCE_STAGE
TO ROLE DATA_ENGINEER;

GRANT WRITE
ON STAGE RETAIL_SUPPLY_CHAIN.RAW.RETAIL_SOURCE_STAGE
TO ROLE DATA_ENGINEER;


-- ------------------------------------------------------------
-- Existing table access
-- ------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES
IN SCHEMA RETAIL_SUPPLY_CHAIN.RAW
TO ROLE DATA_ENGINEER;

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES
IN SCHEMA RETAIL_SUPPLY_CHAIN.SILVER
TO ROLE DATA_ENGINEER;

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES
IN SCHEMA RETAIL_SUPPLY_CHAIN.GOLD
TO ROLE DATA_ENGINEER;

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES
IN SCHEMA RETAIL_SUPPLY_CHAIN.CONTROL
TO ROLE DATA_ENGINEER;


-- ============================================================
-- 2. DATA ANALYST
-- ============================================================

-- ------------------------------------------------------------
-- Database access
-- ------------------------------------------------------------

GRANT USAGE
ON DATABASE RETAIL_SUPPLY_CHAIN
TO ROLE DATA_ANALYST;


-- ------------------------------------------------------------
-- GOLD schema access
-- ------------------------------------------------------------

GRANT USAGE
ON SCHEMA RETAIL_SUPPLY_CHAIN.GOLD
TO ROLE DATA_ANALYST;


-- ------------------------------------------------------------
-- Existing GOLD tables
-- ------------------------------------------------------------

GRANT SELECT
ON ALL TABLES
IN SCHEMA RETAIL_SUPPLY_CHAIN.GOLD
TO ROLE DATA_ANALYST;


-- ------------------------------------------------------------
-- Future GOLD tables
-- ------------------------------------------------------------

GRANT SELECT
ON FUTURE TABLES
IN SCHEMA RETAIL_SUPPLY_CHAIN.GOLD
TO ROLE DATA_ANALYST;


-- ============================================================
-- 3. DATA VIEWER
-- ============================================================

-- ------------------------------------------------------------
-- Database access
-- ------------------------------------------------------------

GRANT USAGE
ON DATABASE RETAIL_SUPPLY_CHAIN
TO ROLE DATA_VIEWER;


-- ------------------------------------------------------------
-- GOLD schema access
-- ------------------------------------------------------------

GRANT USAGE
ON SCHEMA RETAIL_SUPPLY_CHAIN.GOLD
TO ROLE DATA_VIEWER;


-- ------------------------------------------------------------
-- Existing GOLD tables
-- ------------------------------------------------------------

GRANT SELECT
ON ALL TABLES
IN SCHEMA RETAIL_SUPPLY_CHAIN.GOLD
TO ROLE DATA_VIEWER;


-- ------------------------------------------------------------
-- Future GOLD tables
-- ------------------------------------------------------------

GRANT SELECT
ON FUTURE TABLES
IN SCHEMA RETAIL_SUPPLY_CHAIN.GOLD
TO ROLE DATA_VIEWER;


-- ============================================================
-- 4. ROLE HIERARCHY
-- ============================================================

-- DATA_ENGINEER can administer/operate the lower-level roles
-- only if this is how you want the project RBAC hierarchy designed.

-- Example hierarchy:
-- DATA_ENGINEER
--      |
--      +---- DATA_ANALYST
--      |
--      +---- DATA_VIEWER

GRANT ROLE DATA_ANALYST
TO ROLE DATA_ENGINEER;

GRANT ROLE DATA_VIEWER
TO ROLE DATA_ANALYST;
