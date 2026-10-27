USE DATABASE RETAIL_SUPPLY_CHAIN;

CREATE TABLE IF NOT EXISTS CONTROL.PIPELINE_RUNS (
  run_id STRING NOT NULL,
  batch_id STRING,
  entity STRING,
  process_name STRING,
  started_at TIMESTAMP_NTZ NOT NULL,
  completed_at TIMESTAMP_NTZ,
  status STRING NOT NULL,
  records_read NUMBER DEFAULT 0,
  records_rejected NUMBER DEFAULT 0,
  records_written NUMBER DEFAULT 0,
  error_message STRING
);

CREATE TABLE IF NOT EXISTS CONTROL.PIPELINE_MONITORING (
  batch_id STRING,
  entity STRING,
  process_name STRING,
  records_processed NUMBER,
  process_time TIMESTAMP_NTZ,
  status STRING
);

-- Manual checkpoint for the initial load. MERGE keeps this checkpoint rerun-safe.
MERGE INTO CONTROL.PIPELINE_MONITORING t
USING (
  SELECT
    'INITIAL' batch_id,
    'ALL' entity,
    'INITIAL_LOAD' process_name,
    (SELECT COUNT(*) FROM GOLD.FACT_SALES) records_processed,
    CURRENT_TIMESTAMP() process_time,
    'SUCCESS' status
) s
ON t.batch_id = s.batch_id
AND t.entity = s.entity
AND t.process_name = s.process_name
WHEN MATCHED THEN UPDATE SET
  records_processed = s.records_processed,
  process_time = s.process_time,
  status = s.status
WHEN NOT MATCHED THEN INSERT
  (batch_id, entity, process_name, records_processed, process_time, status)
VALUES
  (s.batch_id, s.entity, s.process_name, s.records_processed, s.process_time, s.status);

-- Pipeline runs: latest executions and failures.
SELECT *
FROM CONTROL.PIPELINE_RUNS
ORDER BY started_at DESC;

-- Task execution history.
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  SCHEDULED_TIME_RANGE_START => DATEADD('day', -1, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC;

-- COPY INTO history for RAW ingestion monitoring.
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'RETAIL_SUPPLY_CHAIN.RAW.CUSTOMERS',
  START_TIME => DATEADD('day', -7, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC;
