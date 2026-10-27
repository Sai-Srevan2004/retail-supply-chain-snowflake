USE DATABASE RETAIL_SUPPLY_CHAIN;

CREATE TABLE IF NOT EXISTS GOLD.FACT_SALES (
  sale_key NUMBER AUTOINCREMENT START 1 INCREMENT 1,
  sale_id STRING NOT NULL,
  date_key NUMBER NOT NULL,
  customer_key NUMBER NOT NULL,
  product_key NUMBER NOT NULL,
  store_key NUMBER NOT NULL,
  sale_timestamp TIMESTAMP_NTZ NOT NULL,
  quantity NUMBER NOT NULL,
  unit_price NUMBER(12,2) NOT NULL,
  discount NUMBER(12,2) NOT NULL,
  gross_amount NUMBER(14,2) NOT NULL,
  discount_amount NUMBER(14,2) NOT NULL,
  net_amount NUMBER(14,2) NOT NULL,
  payment_method STRING,
  _source_file STRING,
  _batch_id STRING,
  _loaded_at TIMESTAMP_NTZ,
  CONSTRAINT PK_FACT_SALES PRIMARY KEY (sale_key)
);

-- Historical customer lookup uses the SCD2 validity interval.
INSERT INTO GOLD.FACT_SALES
(sale_id, date_key, customer_key, product_key, store_key, sale_timestamp,
 quantity, unit_price, discount, gross_amount, discount_amount, net_amount,
 payment_method, _source_file, _batch_id, _loaded_at)
SELECT s.sale_id,
       TO_NUMBER(TO_CHAR(s.sale_timestamp::DATE, 'YYYYMMDD')),
       c.customer_key,
       p.product_key,
       st.store_key,
       s.sale_timestamp,
       s.quantity,
       s.unit_price,
       s.discount_amount,
       s.quantity * s.unit_price AS gross_amount,
       s.discount_amount,
       (s.quantity * s.unit_price) - s.discount_amount AS net_amount,
       s.payment_method,
       s._source_file, s._batch_id, s._loaded_at
FROM SILVER.SALES s
JOIN GOLD.DIM_CUSTOMER c
  ON c.customer_id = s.customer_id
 AND c.effective_start_date <= s.sale_timestamp
 AND s.sale_timestamp < c.effective_end_date
JOIN GOLD.DIM_PRODUCT p ON p.product_id = s.product_id
JOIN GOLD.DIM_STORE st ON st.store_id = s.store_id
WHERE NOT EXISTS (SELECT 1 FROM GOLD.FACT_SALES f WHERE f.sale_id = s.sale_id);
