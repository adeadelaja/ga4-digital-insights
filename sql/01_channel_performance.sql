-- 01_channel_performance.sql
-- Question: which channels bring engaged sessions and revenue, and how well does each one convert?
-- Grain: one row per channel. A session is user_pseudo_id + ga_session_id.
-- Session source and medium = the first source and medium recorded in the session (GA4 stores them on events).
-- Save the result as results/01_channel_performance.csv

CREATE TEMP FUNCTION channel_group(source STRING, medium STRING) AS (
  -- Simplified version of the GA4 default channel group.
  -- The sample is obfuscated: Google replaced some values with '<Other>' or '(data deleted)'.
  CASE
    WHEN source IS NULL OR source = '(direct)' THEN 'Direct'
    WHEN source = '(data deleted)' OR medium = '(data deleted)' THEN 'Data deleted'
    WHEN source = '<Other>' OR medium = '<Other>' THEN 'Other (obfuscated)'
    WHEN medium = 'organic' THEN 'Organic Search'
    WHEN REGEXP_CONTAINS(medium, r'^(cpc|ppc|paidsearch)$') THEN 'Paid Search'
    WHEN REGEXP_CONTAINS(medium, r'^(display|banner|cpm)$') THEN 'Display'
    WHEN REGEXP_CONTAINS(medium, r'paid.*social|^paid_social$') THEN 'Paid Social'
    WHEN REGEXP_CONTAINS(medium, r'^(social|social_network|social_media|sm)$') THEN 'Organic Social'
    WHEN REGEXP_CONTAINS(LOWER(CONCAT(source, ' ', medium)), r'email|e_mail|newsletter') THEN 'Email'
    WHEN medium = 'affiliate' THEN 'Affiliates'
    WHEN medium = 'referral' THEN 'Referral'
    ELSE 'Unassigned'
  END
);

WITH events AS (
  SELECT
    user_pseudo_id,
    event_name,
    event_timestamp,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source') AS source,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium') AS medium,
    (SELECT COALESCE(value.string_value, CAST(value.int_value AS STRING)) FROM UNNEST(event_params) WHERE key = 'session_engaged') AS session_engaged,
    ecommerce.purchase_revenue_in_usd AS revenue_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

sessions AS (
  SELECT
    user_pseudo_id,
    CONCAT(user_pseudo_id, '.', CAST(ga_session_id AS STRING)) AS session_key,
    ARRAY_AGG(IF(source IS NOT NULL, STRUCT(source, medium), NULL) IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS traffic,
    MAX(IF(session_engaged = '1', 1, 0)) AS engaged,
    MAX(IF(event_name = 'purchase', 1, 0)) AS converted,
    SUM(IF(event_name = 'purchase', COALESCE(revenue_usd, 0), 0)) AS revenue_usd
  FROM events
  WHERE ga_session_id IS NOT NULL
  GROUP BY user_pseudo_id, session_key
),

by_channel AS (
  SELECT
    channel_group(traffic.source, traffic.medium) AS channel,
    COUNT(*) AS sessions,
    COUNT(DISTINCT user_pseudo_id) AS users,
    SUM(engaged) AS engaged_sessions,
    SUM(converted) AS converting_sessions,
    SUM(revenue_usd) AS revenue_usd
  FROM sessions
  GROUP BY channel
)

SELECT
  channel,
  sessions,
  users,
  engaged_sessions,
  ROUND(SAFE_DIVIDE(engaged_sessions, sessions), 4) AS engagement_rate,
  converting_sessions,
  ROUND(SAFE_DIVIDE(converting_sessions, sessions), 4) AS session_conversion_rate,
  ROUND(revenue_usd, 2) AS revenue_usd,
  ROUND(SAFE_DIVIDE(revenue_usd, sessions), 2) AS revenue_per_session_usd,
  ROUND(SAFE_DIVIDE(sessions, SUM(sessions) OVER ()), 4) AS share_of_sessions,
  ROUND(SAFE_DIVIDE(revenue_usd, SUM(revenue_usd) OVER ()), 4) AS share_of_revenue
FROM by_channel
ORDER BY revenue_usd DESC;
