-- ============================================================
-- RETAIL SUPPLY CHAIN DATA ENGINEERING PROJECT
-- DATABASE + SCHEMA FOUNDATION
-- ============================================================


-- ------------------------------------------------------------
-- 1. CREATE DATABASE
-- ------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS RETAIL_SUPPLY_CHAIN;


-- ------------------------------------------------------------
-- 2. USE DATABASE
-- ------------------------------------------------------------

USE DATABASE RETAIL_SUPPLY_CHAIN;


-- ------------------------------------------------------------
-- 3. CREATE MEDALLION SCHEMAS
-- ------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS RAW;

CREATE SCHEMA IF NOT EXISTS SILVER;

CREATE SCHEMA IF NOT EXISTS GOLD;

CREATE SCHEMA IF NOT EXISTS CONTROL;


-- ------------------------------------------------------------
-- 4. VERIFY DATABASE
-- ------------------------------------------------------------

SHOW SCHEMAS IN DATABASE RETAIL_SUPPLY_CHAIN;