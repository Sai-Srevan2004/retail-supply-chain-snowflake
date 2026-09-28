/* ============================================================
   SILVER TASKS
   ============================================================ */


/* ------------------------------------------------------------
   CUSTOMER SILVER TASK
   ------------------------------------------------------------ */

CREATE OR REPLACE TASK SILVER.TASK_CUSTOMER_INCREMENTAL
    WAREHOUSE = RETAIL_WH
    SCHEDULE = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA(
        'RETAIL_SUPPLY_CHAIN.RAW.CUSTOMER_STREAM'
    )
AS
    CALL SILVER.PROCESS_CUSTOMER_INCREMENTAL();


/* ------------------------------------------------------------
   PRODUCT SILVER TASK
   ------------------------------------------------------------ */

CREATE OR REPLACE TASK SILVER.TASK_PRODUCT_INCREMENTAL
    WAREHOUSE = RETAIL_WH
    SCHEDULE = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA(
        'RETAIL_SUPPLY_CHAIN.RAW.PRODUCT_STREAM'
    )
AS
    CALL SILVER.PROCESS_PRODUCT_INCREMENTAL();


/* ------------------------------------------------------------
   SALES SILVER TASK
   ------------------------------------------------------------ */

CREATE OR REPLACE TASK SILVER.TASK_SALES_INCREMENTAL
    WAREHOUSE = RETAIL_WH
    SCHEDULE = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA(
        'RETAIL_SUPPLY_CHAIN.RAW.SALES_STREAM'
    )
AS
    CALL SILVER.PROCESS_SALES_INCREMENTAL();


/* ============================================================
   GOLD TASKS
   ============================================================ */


/* ------------------------------------------------------------
   CUSTOMER SCD2 GOLD TASK
   ------------------------------------------------------------ */

CREATE OR REPLACE TASK SILVER.GOLD_TASK_CUSTOMER_SCD2
    WAREHOUSE = RETAIL_WH
    AFTER SILVER.TASK_CUSTOMER_INCREMENTAL
    WHEN SYSTEM$STREAM_HAS_DATA(
        'RETAIL_SUPPLY_CHAIN.SILVER.CUSTOMERS_STREAM'
    )
AS
    CALL GOLD.PROCESS_CUSTOMER_SCD2();


/* ------------------------------------------------------------
   PRODUCT GOLD TASK
   ------------------------------------------------------------ */

CREATE OR REPLACE TASK SILVER.GOLD_TASK_PRODUCT_INCREMENTAL
    WAREHOUSE = RETAIL_WH
    AFTER SILVER.TASK_PRODUCT_INCREMENTAL
    WHEN SYSTEM$STREAM_HAS_DATA(
        'RETAIL_SUPPLY_CHAIN.SILVER.PRODUCTS_STREAM'
    )
AS
    CALL GOLD.PROCESS_PRODUCT_INCREMENTAL();


/* ------------------------------------------------------------
   SALES GOLD TASK
   ------------------------------------------------------------ */

CREATE OR REPLACE TASK SILVER.GOLD_TASK_SALES_INCREMENTAL
    WAREHOUSE = RETAIL_WH
    AFTER SILVER.TASK_SALES_INCREMENTAL
    WHEN SYSTEM$STREAM_HAS_DATA(
        'RETAIL_SUPPLY_CHAIN.SILVER.SALES_STREAM'
    )
AS
    CALL GOLD.PROCESS_SALES_INCREMENTAL();


/* ============================================================
   CHECK TASK DEFINITIONS
   ============================================================ */

SHOW TASKS IN SCHEMA SILVER;

SHOW TASKS IN SCHEMA GOLD;


/* ============================================================
   --RESUMES TASKS
   ============================================================ */

ALTER TASK SILVER.GOLD_TASK_CUSTOMER_SCD2 RESUME;

ALTER TASK SILVER.GOLD_TASK_PRODUCT_INCREMENTAL RESUME;

ALTER TASK SILVER.GOLD_TASK_SALES_INCREMENTAL RESUME;
