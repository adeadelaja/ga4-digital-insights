-- 00_dataset_profile.sql
-- Question: what is in the sample, and how big is it?
-- Dataset: bigquery-public-data.ga4_obfuscated_sample_ecommerce (Google Merchandise Store, 1 Nov 2020 to 31 Jan 2021)
-- Save the result as results/00_dataset_profile.csv

WITH events AS (
  SELECT
    event_date,
    event_name,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    ecommerce.purchase_revenue_in_usd AS revenue_usd,
    ecommerce.transaction_id AS transaction_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)

SELECT
  MIN(PARSE_DATE('%Y%m%d', event_date)) AS first_day,
  MAX(PARSE_DATE('%Y%m%d', event_date)) AS last_day,
  COUNT(DISTINCT event_date) AS days,
  COUNT(*) AS events,
  COUNT(DISTINCT event_name) AS distinct_event_names,
  COUNT(DISTINCT user_pseudo_id) AS users,
  COUNT(DISTINCT IF(ga_session_id IS NOT NULL, CONCAT(user_pseudo_id, '.', CAST(ga_session_id AS STRING)), NULL)) AS sessions,
  COUNTIF(event_name = 'purchase') AS purchase_events,
  COUNT(DISTINCT IF(event_name = 'purchase' AND transaction_id NOT IN ('(not set)', ''), transaction_id, NULL)) AS distinct_transactions,
  ROUND(SUM(IF(event_name = 'purchase', revenue_usd, 0)), 2) AS revenue_usd
FROM events;
