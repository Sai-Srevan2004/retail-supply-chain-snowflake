/* ============================================================
   RETAIL SUPPLY CHAIN - SNOWFLAKE TASK ORCHESTRATION
   ============================================================ */

/* ------------------------------------------------------------
   CUSTOMER SILVER PROCEDURE
   ------------------------------------------------------------ */

CREATE OR REPLACE PROCEDURE SILVER.PROCESS_CUSTOMER_INCREMENTAL()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;

CREATE OR REPLACE TEMPORARY TABLE CUSTOMERS_INCREMENTAL_VALIDATED AS

SELECT
    TRIM(r.customer_id) AS customer_id,
    NULLIF(TRIM(r.customer_name), '') AS customer_name,
    LOWER(NULLIF(TRIM(r.email), '')) AS email,
    NULLIF(TRIM(r.phone), '') AS phone,

    UPPER(NULLIF(TRIM(r.region), '')) AS region,
    UPPER(NULLIF(TRIM(r.segment), '')) AS segment,

    TRY_TO_TIMESTAMP_NTZ(r.created_at) AS created_at,
    TRY_TO_TIMESTAMP_NTZ(r.updated_at) AS updated_at,

    r._source_file,
    r._batch_id,
    r._loaded_at,
    r._row_number,

    OBJECT_CONSTRUCT(
        'customer_id',   r.customer_id,
        'customer_name', r.customer_name,
        'email',         r.email,
        'phone',         r.phone,
        'region',        r.region,
        'segment',       r.segment,
        'created_at',    r.created_at,
        'updated_at',    r.updated_at
    ) AS raw_record,

    ARRAY_CONSTRUCT_COMPACT(

        CASE
            WHEN NULLIF(TRIM(r.customer_id), '') IS NULL
            THEN 'MISSING_CUSTOMER_ID'
        END,

        CASE
            WHEN NULLIF(TRIM(r.customer_name), '') IS NULL
            THEN 'MISSING_CUSTOMER_NAME'
        END,

        CASE
            WHEN NULLIF(TRIM(r.email), '') IS NOT NULL
             AND NOT REGEXP_LIKE(
                    TRIM(r.email),
                    '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
                 )
            THEN 'INVALID_EMAIL_FORMAT'
        END,

        CASE
            WHEN NULLIF(TRIM(r.phone), '') IS NOT NULL
             AND NOT REGEXP_LIKE(
                    TRIM(r.phone),
                    '^[0-9+() -]{7,20}$'
                 )
            THEN 'INVALID_PHONE_FORMAT'
        END,

        CASE
            WHEN TRY_TO_TIMESTAMP_NTZ(r.created_at) IS NULL
            THEN 'INVALID_CREATED_AT'
        END,

        CASE
            WHEN TRY_TO_TIMESTAMP_NTZ(r.updated_at) IS NULL
            THEN 'INVALID_UPDATED_AT'
        END

    ) AS rejection_reasons,

    CASE
        WHEN ARRAY_SIZE(rejection_reasons) = 0
        THEN 'VALID'
        ELSE 'INVALID'
    END AS validation_status

FROM RAW.CUSTOMER_STREAM r;


--records to rejection table which are invalid

INSERT INTO SILVER.REJECTED_RECORDS (
    source_file,
    entity_name,
    business_key,
    rejection_reason,
    raw_record,
    batch_id
)
SELECT
    _source_file,
    'CUSTOMER',
    customer_id,
    ARRAY_TO_STRING(rejection_reasons, '; '),
    raw_record,
    _batch_id
FROM CUSTOMERS_INCREMENTAL_VALIDATED
WHERE validation_status = 'INVALID';


--now merge correct records

MERGE INTO SILVER.CUSTOMERS AS tgt

USING (
    SELECT
        customer_id,
        customer_name,
        email,
        phone,
        region,
        segment,
        created_at,
        updated_at,
        _source_file,
        _batch_id,
        _loaded_at

    FROM CUSTOMERS_INCREMENTAL_VALIDATED

    WHERE validation_status = 'VALID'

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY customer_id
        ORDER BY
            updated_at DESC NULLS LAST,
            _loaded_at DESC,
            _row_number DESC
    ) = 1

) AS src

ON tgt.customer_id = src.customer_id

WHEN MATCHED
     AND (
            src.updated_at > tgt.updated_at
            OR tgt.updated_at IS NULL
         )

THEN UPDATE SET

    tgt.customer_name = src.customer_name,
    tgt.email         = src.email,
    tgt.phone         = src.phone,
    tgt.region        = src.region,
    tgt.segment       = src.segment,
    tgt.created_at    = src.created_at,
    tgt.updated_at    = src.updated_at,
    tgt._source_file  = src._source_file,
    tgt._batch_id     = src._batch_id,
    tgt._loaded_at    = src._loaded_at

WHEN NOT MATCHED

THEN INSERT (
    customer_id,
    customer_name,
    email,
    phone,
    region,
    segment,
    created_at,
    updated_at,
    _source_file,
    _batch_id,
    _loaded_at
)

VALUES (
    src.customer_id,
    src.customer_name,
    src.email,
    src.phone,
    src.region,
    src.segment,
    src.created_at,
    src.updated_at,
    src._source_file,
    src._batch_id,
    src._loaded_at
);

    RETURN 'CUSTOMER SILVER PROCESS COMPLETED';

END;
$$;


/* ------------------------------------------------------------
   PRODUCT SILVER PROCEDURE
   ------------------------------------------------------------ */

CREATE OR REPLACE PROCEDURE SILVER.PROCESS_PRODUCT_INCREMENTAL()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


CREATE OR REPLACE TEMPORARY TABLE PRODUCTS_INCREMENTAL_VALIDATED AS

SELECT
    TRIM(p.product_id) AS product_id,

    NULLIF(TRIM(p.product_name), '') AS product_name,

    UPPER(NULLIF(TRIM(p.category), '')) AS category,

    NULLIF(TRIM(p.brand), '') AS brand,

    NULLIF(TRIM(p.supplier_id), '') AS supplier_id,

    TRY_TO_DECIMAL(
        NULLIF(TRIM(p.unit_price), ''),
        12,
        2
    ) AS unit_price,

    TRY_TO_TIMESTAMP_NTZ(p.created_at) AS created_at,

    TRY_TO_TIMESTAMP_NTZ(p.updated_at) AS updated_at,

    p._source_file,
    p._batch_id,
    p._loaded_at,
    p._row_number,

    OBJECT_CONSTRUCT(
        'product_id',   p.product_id,
        'product_name', p.product_name,
        'category',     p.category,
        'brand',        p.brand,
        'supplier_id',  p.supplier_id,
        'unit_price',   p.unit_price,
        'created_at',   p.created_at,
        'updated_at',   p.updated_at
    ) AS raw_record,

    ARRAY_CONSTRUCT_COMPACT(

        CASE
            WHEN NULLIF(TRIM(p.product_id), '') IS NULL
            THEN 'MISSING_PRODUCT_ID'
        END,

        CASE
            WHEN NULLIF(TRIM(p.product_name), '') IS NULL
            THEN 'MISSING_PRODUCT_NAME'
        END,

        CASE
            WHEN TRY_TO_DECIMAL(
                    NULLIF(TRIM(p.unit_price), ''),
                    12,
                    2
                 ) IS NULL
            THEN 'INVALID_UNIT_PRICE_FORMAT'
        END,

        CASE
            WHEN TRY_TO_DECIMAL(
                    NULLIF(TRIM(p.unit_price), ''),
                    12,
                    2
                 ) IS NOT NULL
             AND TRY_TO_DECIMAL(
                    NULLIF(TRIM(p.unit_price), ''),
                    12,
                    2
                 ) <= 0
            THEN 'NON_POSITIVE_UNIT_PRICE'
        END,

        CASE
            WHEN NULLIF(TRIM(p.supplier_id), '') IS NULL
            THEN 'MISSING_SUPPLIER_ID'
        END,

        CASE
            WHEN NULLIF(TRIM(p.supplier_id), '') IS NOT NULL
             AND NOT EXISTS (
                 SELECT 1
                 FROM SILVER.SUPPLIERS s
                 WHERE s.supplier_id = TRIM(p.supplier_id)
             )
            THEN 'UNKNOWN_SUPPLIER_ID'
        END,

        CASE
            WHEN TRY_TO_TIMESTAMP_NTZ(p.created_at) IS NULL
            THEN 'INVALID_CREATED_AT'
        END,

        CASE
            WHEN TRY_TO_TIMESTAMP_NTZ(p.updated_at) IS NULL
            THEN 'INVALID_UPDATED_AT'
        END

    ) AS rejection_reasons,

    CASE
        WHEN ARRAY_SIZE(rejection_reasons) = 0
        THEN 'VALID'
        ELSE 'INVALID'
    END AS validation_status

FROM RAW.PRODUCT_STREAM p;


--rejected invalid records
----------------------------


INSERT INTO SILVER.REJECTED_RECORDS (
    source_file,
    entity_name,
    business_key,
    rejection_reason,
    raw_record,
    batch_id
)
SELECT
    _source_file,
    'PRODUCT',
    product_id,
    ARRAY_TO_STRING(rejection_reasons, '; '),
    raw_record,
    _batch_id
FROM PRODUCTS_INCREMENTAL_VALIDATED
WHERE validation_status = 'INVALID';


--merger valid records
---------------------

MERGE INTO SILVER.PRODUCTS AS tgt

USING (
    SELECT
        product_id,
        product_name,
        category,
        brand,
        supplier_id,
        unit_price,
        created_at,
        updated_at,
        _source_file,
        _batch_id,
        _loaded_at

    FROM PRODUCTS_INCREMENTAL_VALIDATED

    WHERE validation_status = 'VALID'

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY product_id
        ORDER BY
            updated_at DESC NULLS LAST,
            _loaded_at DESC,
            _row_number DESC
    ) = 1

) AS src

ON tgt.product_id = src.product_id

WHEN MATCHED
     AND (
            src.updated_at > tgt.updated_at
            OR tgt.updated_at IS NULL
         )

THEN UPDATE SET

    tgt.product_name = src.product_name,
    tgt.category     = src.category,
    tgt.brand        = src.brand,
    tgt.supplier_id  = src.supplier_id,
    tgt.unit_price   = src.unit_price,
    tgt.created_at   = src.created_at,
    tgt.updated_at   = src.updated_at,
    tgt._source_file = src._source_file,
    tgt._batch_id    = src._batch_id,
    tgt._loaded_at   = src._loaded_at

WHEN NOT MATCHED

THEN INSERT (
    product_id,
    product_name,
    category,
    brand,
    supplier_id,
    unit_price,
    created_at,
    updated_at,
    _source_file,
    _batch_id,
    _loaded_at
)

VALUES (
    src.product_id,
    src.product_name,
    src.category,
    src.brand,
    src.supplier_id,
    src.unit_price,
    src.created_at,
    src.updated_at,
    src._source_file,
    src._batch_id,
    src._loaded_at
);

    RETURN 'PRODUCT SILVER PROCESS COMPLETED';

END;
$$;


/* ------------------------------------------------------------
   SALES SILVER PROCEDURE
   ------------------------------------------------------------ */

CREATE OR REPLACE PROCEDURE SILVER.PROCESS_SALES_INCREMENTAL()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA SILVER;


CREATE OR REPLACE TEMPORARY TABLE SALES_INCREMENTAL_VALIDATED AS

WITH cleaned AS (

    SELECT
        TRIM(s.sale_id) AS sale_id,

        TRIM(s.customer_id) AS customer_id,

        TRIM(s.product_id) AS product_id,

        TRIM(s.store_id) AS store_id,

        TRY_TO_DATE(s.sale_date) AS sale_date,

        TRY_TO_NUMBER(
            NULLIF(TRIM(s.quantity), '')
        ) AS quantity,

        TRY_TO_DECIMAL(
            NULLIF(TRIM(s.unit_price), ''),
            12,
            2
        ) AS unit_price,

        TRY_TO_DECIMAL(
            NULLIF(TRIM(s.discount), ''),
            5,
            2
        ) AS discount,

        UPPER(NULLIF(TRIM(s.payment_method), '')) AS payment_method,

        s._source_file,
        s._batch_id,
        s._loaded_at,
        s._row_number,

        OBJECT_CONSTRUCT(
            'sale_id',        s.sale_id,
            'customer_id',    s.customer_id,
            'product_id',     s.product_id,
            'store_id',       s.store_id,
            'sale_date',      s.sale_date,
            'quantity',       s.quantity,
            'unit_price',     s.unit_price,
            'discount',       s.discount,
            'payment_method', s.payment_method
        ) AS raw_record

    FROM RAW.SALES_STREAM s
)

SELECT
    cln.sale_id,
    cln.customer_id,
    cln.product_id,
    cln.store_id,
    cln.sale_date,
    cln.quantity,
    cln.unit_price,
    cln.discount,
    cln.payment_method,

    cln._source_file,
    cln._batch_id,
    cln._loaded_at,
    cln._row_number,

    cln.raw_record,

    ARRAY_CONSTRUCT_COMPACT(

        CASE
            WHEN cln.sale_id IS NULL
            THEN 'MISSING_SALE_ID'
        END,

        CASE
            WHEN cln.customer_id IS NULL
            THEN 'MISSING_CUSTOMER_ID'
        END,

        CASE
            WHEN cln.product_id IS NULL
            THEN 'MISSING_PRODUCT_ID'
        END,

        CASE
            WHEN cln.store_id IS NULL
            THEN 'MISSING_STORE_ID'
        END,

        CASE
            WHEN cln.sale_date IS NULL
            THEN 'INVALID_SALE_DATE'
        END,

        CASE
            WHEN cln.quantity IS NULL
            THEN 'INVALID_QUANTITY_FORMAT'
        END,

        CASE
            WHEN cln.quantity IS NOT NULL
             AND cln.quantity <= 0
            THEN 'NON_POSITIVE_QUANTITY'
        END,

        CASE
            WHEN cln.unit_price IS NULL
            THEN 'INVALID_UNIT_PRICE_FORMAT'
        END,

        CASE
            WHEN cln.unit_price IS NOT NULL
             AND cln.unit_price <= 0
            THEN 'NON_POSITIVE_UNIT_PRICE'
        END,

        CASE
            WHEN cln.discount IS NULL
            THEN 'INVALID_DISCOUNT_FORMAT'
        END,

        CASE
            WHEN cln.discount IS NOT NULL
             AND cln.discount NOT BETWEEN 0 AND 1
            THEN 'DISCOUNT_OUT_OF_RANGE'
        END,

        CASE
            WHEN cln.payment_method IS NULL
              OR cln.payment_method NOT IN (
                    'CASH',
                    'COD',
                    'CARD',
                    'UPI',
                    'NET_BANKING',
                    'WALLET'
                 )
            THEN 'INVALID_PAYMENT_METHOD'
        END,

        CASE
            WHEN cln.customer_id IS NOT NULL
             AND NOT EXISTS (
                 SELECT 1
                 FROM SILVER.CUSTOMERS c
                 WHERE c.customer_id = cln.customer_id
             )
            THEN 'UNKNOWN_CUSTOMER_ID'
        END,

        CASE
            WHEN cln.product_id IS NOT NULL
             AND NOT EXISTS (
                 SELECT 1
                 FROM SILVER.PRODUCTS p
                 WHERE p.product_id = cln.product_id
             )
            THEN 'UNKNOWN_PRODUCT_ID'
        END,

        CASE
            WHEN cln.store_id IS NOT NULL
             AND NOT EXISTS (
                 SELECT 1
                 FROM SILVER.STORES st
                 WHERE st.store_id = cln.store_id
             )
            THEN 'UNKNOWN_STORE_ID'
        END

    ) AS rejection_reasons,

    CASE
        WHEN ARRAY_SIZE(rejection_reasons) = 0
        THEN 'VALID'
        ELSE 'INVALID'
    END AS validation_status

FROM cleaned cln;


--reject invalid records
---------------------------

INSERT INTO SILVER.REJECTED_RECORDS (
    source_file,
    entity_name,
    business_key,
    rejection_reason,
    raw_record,
    batch_id
)
SELECT
    _source_file,
    'SALE',
    sale_id,
    ARRAY_TO_STRING(rejection_reasons, '; '),
    raw_record,
    _batch_id
FROM SALES_INCREMENTAL_VALIDATED
WHERE validation_status = 'INVALID';


--merge valid records
-----------------------

MERGE INTO SILVER.SALES AS tgt

USING (

    SELECT
        sale_id,
        customer_id,
        product_id,
        store_id,
        sale_date,
        quantity,
        unit_price,
        discount,
        payment_method,

        _source_file,
        _batch_id,
        _loaded_at

    FROM SALES_INCREMENTAL_VALIDATED

    WHERE validation_status = 'VALID'

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY sale_id
        ORDER BY
            _loaded_at DESC,
            _row_number DESC
    ) = 1

) AS src

ON tgt.sale_id = src.sale_id


WHEN MATCHED THEN UPDATE SET

    tgt.customer_id    = src.customer_id,
    tgt.product_id     = src.product_id,
    tgt.store_id       = src.store_id,
    tgt.sale_date      = src.sale_date,
    tgt.quantity       = src.quantity,
    tgt.unit_price     = src.unit_price,
    tgt.discount       = src.discount,
    tgt.payment_method = src.payment_method,

    tgt._source_file   = src._source_file,
    tgt._batch_id      = src._batch_id,
    tgt._loaded_at     = src._loaded_at


WHEN NOT MATCHED THEN INSERT (

    sale_id,
    customer_id,
    product_id,
    store_id,
    sale_date,
    quantity,
    unit_price,
    discount,
    payment_method,

    _source_file,
    _batch_id,
    _loaded_at

)

VALUES (

    src.sale_id,
    src.customer_id,
    src.product_id,
    src.store_id,
    src.sale_date,
    src.quantity,
    src.unit_price,
    src.discount,
    src.payment_method,

    src._source_file,
    src._batch_id,
    src._loaded_at
);

    RETURN 'SALES SILVER PROCESS COMPLETED';

END;
$$;


/* ============================================================
   PART 2
   GOLD PROCEDURES
   ============================================================ */


/* ------------------------------------------------------------
   CUSTOMER GOLD SCD TYPE 2
   ------------------------------------------------------------ */

CREATE OR REPLACE PROCEDURE GOLD.PROCESS_CUSTOMER_SCD2()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA GOLD;


    CREATE OR REPLACE TEMPORARY TABLE SILVER_STREAM_DATA_CUSTOMERS AS
SELECT customer_id, customer_name, email, phone, region, segment,
       created_at, updated_at, _source_file, _batch_id, _loaded_at
FROM SILVER.CUSTOMERS_STREAM
WHERE METADATA$ACTION = 'INSERT';


-- ------------------------------------------------------------
-- Step 1: expire current DIM_CUSTOMER rows whose tracked attributes
-- changed, comparing only against the rows Silver actually touched.
-- ------------------------------------------------------------
MERGE INTO GOLD.DIM_CUSTOMER AS tgt
USING SILVER_STREAM_DATA_CUSTOMERS AS src
ON tgt.customer_id = src.customer_id
   AND tgt.is_current = TRUE
WHEN MATCHED AND (
        NVL(tgt.customer_name, '') <> NVL(src.customer_name, '')
     OR NVL(tgt.email, '')         <> NVL(src.email, '')
     OR NVL(tgt.phone, '')         <> NVL(src.phone, '')
     OR NVL(tgt.region, '')        <> NVL(src.region, '')
     OR NVL(tgt.segment, '')       <> NVL(src.segment, '')
) THEN UPDATE SET
    is_current         = FALSE,
    effective_end_date = COALESCE(src.updated_at, src.created_at, src._loaded_at);


-- ------------------------------------------------------------
-- Step 2: insert a new current version for:
--   (a) customer_ids with no current dimension row at all (new), and
--   (b) customer_ids whose current row was just expired in step 1
--       (attributes changed).
-- Both cases collapse to the same condition: no existing row is both
-- current AND attribute-identical to the incoming source row.
-- ------------------------------------------------------------
INSERT INTO GOLD.DIM_CUSTOMER (
    customer_id,
    customer_name,
    email,
    phone,
    region,
    segment,
    effective_start_date,
    effective_end_date,
    is_current,
    _source_file,
    _batch_id,
    _loaded_at
)
SELECT
    src.customer_id,
    src.customer_name,
    src.email,
    src.phone,
    src.region,
    src.segment,
    COALESCE(src.updated_at, src.created_at, src._loaded_at) AS effective_start_date,
    '9999-12-31 23:59:59.000'::TIMESTAMP_NTZ AS effective_end_date,
    TRUE AS is_current,
    src._source_file,
    src._batch_id,
    src._loaded_at
FROM SILVER_STREAM_DATA_CUSTOMERS src
WHERE NOT EXISTS (
    SELECT 1
    FROM GOLD.DIM_CUSTOMER d
    WHERE d.customer_id = src.customer_id
      AND d.is_current = TRUE
      AND NVL(d.customer_name, '') = NVL(src.customer_name, '')
      AND NVL(d.email, '')         = NVL(src.email, '')
      AND NVL(d.phone, '')         = NVL(src.phone, '')
      AND NVL(d.region, '')        = NVL(src.region, '')
      AND NVL(d.segment, '')       = NVL(src.segment, '')
);

    RETURN 'CUSTOMER SCD2 COMPLETED';

END;
$$;


/* ------------------------------------------------------------
   PRODUCT GOLD
   ------------------------------------------------------------ */

CREATE OR REPLACE PROCEDURE GOLD.PROCESS_PRODUCT_INCREMENTAL()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA GOLD;


MERGE INTO GOLD.DIM_PRODUCT AS tgt
USING (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        p.brand,
        p.supplier_id,
        ds.supplier_key,
        p.unit_price,
        p.created_at,
        p.updated_at,
        p._source_file,
        p._batch_id,
        p._loaded_at
    FROM SILVER.PRODUCTS_STREAM p
    LEFT JOIN GOLD.DIM_SUPPLIER ds
        ON p.supplier_id = ds.supplier_id
    WHERE p.METADATA$ACTION = 'INSERT'
) AS src
ON tgt.product_id = src.product_id

WHEN MATCHED AND (src.updated_at > tgt.updated_at OR tgt.updated_at IS NULL)
THEN UPDATE SET
    product_name  = src.product_name,
    category      = src.category,
    brand         = src.brand,
    supplier_id   = src.supplier_id,
    supplier_key  = src.supplier_key,
    unit_price    = src.unit_price,
    created_at    = src.created_at,
    updated_at    = src.updated_at,
    _source_file  = src._source_file,
    _batch_id     = src._batch_id,
    _loaded_at    = src._loaded_at

WHEN NOT MATCHED THEN INSERT (
    product_id, product_name, category, brand,
    supplier_id, supplier_key, unit_price,
    created_at, updated_at,
    _source_file, _batch_id, _loaded_at
) VALUES (
    src.product_id, src.product_name, src.category, src.brand,
    src.supplier_id, src.supplier_key, src.unit_price,
    src.created_at, src.updated_at,
    src._source_file, src._batch_id, src._loaded_at
);


    RETURN 'PRODUCT GOLD PROCESS COMPLETED';

END;
$$;


/* ------------------------------------------------------------
   SALES GOLD
   ------------------------------------------------------------ */

CREATE OR REPLACE PROCEDURE GOLD.PROCESS_SALES_INCREMENTAL()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

USE WAREHOUSE RETAIL_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA GOLD;



MERGE INTO GOLD.FACT_SALES AS tgt
USING (
    SELECT
        s.sale_id,
        d.date_key,
        c.customer_key,
        p.product_key,
        p.supplier_key,
        st.store_key,
        s.sale_date,
        s.quantity,
        s.unit_price,
        s.discount,
        s.quantity * s.unit_price                       AS gross_amount,
        s.quantity * s.unit_price * s.discount           AS discount_amount,
        s.quantity * s.unit_price * (1 - s.discount)     AS net_amount,
        s.payment_method,
        s._source_file,
        s._batch_id,
        s._loaded_at
    FROM SILVER.SALES_STREAM s

    INNER JOIN GOLD.DIM_DATE d
        ON s.sale_date = d.full_date

    INNER JOIN GOLD.DIM_CUSTOMER c
        ON s.customer_id = c.customer_id
       AND c.is_current = TRUE

    INNER JOIN GOLD.DIM_PRODUCT p
        ON s.product_id = p.product_id

    INNER JOIN GOLD.DIM_STORE st
        ON s.store_id = st.store_id

    WHERE s.METADATA$ACTION = 'INSERT'
) AS src
ON tgt.sale_id = src.sale_id

WHEN MATCHED THEN UPDATE SET
    date_key         = src.date_key,
    customer_key     = src.customer_key,
    product_key      = src.product_key,
    supplier_key     = src.supplier_key,
    store_key        = src.store_key,
    sale_date        = src.sale_date,
    quantity         = src.quantity,
    unit_price       = src.unit_price,
    discount         = src.discount,
    gross_amount     = src.gross_amount,
    discount_amount  = src.discount_amount,
    net_amount       = src.net_amount,
    payment_method   = src.payment_method,
    _source_file     = src._source_file,
    _batch_id        = src._batch_id,
    _loaded_at       = src._loaded_at

WHEN NOT MATCHED THEN INSERT (
    sale_id, date_key, customer_key, product_key, supplier_key, store_key,
    sale_date, quantity, unit_price, discount,
    gross_amount, discount_amount, net_amount,
    payment_method, _source_file, _batch_id, _loaded_at
) VALUES (
    src.sale_id, src.date_key, src.customer_key, src.product_key,
    src.supplier_key, src.store_key,
    src.sale_date, src.quantity, src.unit_price, src.discount,
    src.gross_amount, src.discount_amount, src.net_amount,
    src.payment_method, src._source_file, src._batch_id, src._loaded_at
);



    RETURN 'SALES GOLD PROCESS COMPLETED';

END;
$$;


