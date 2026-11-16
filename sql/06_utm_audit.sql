-- 06_utm_audit.sql
-- Question: are campaign tags following the naming standard in tracking/utm_naming_standard.md?
-- Lists every session source and medium pair with its sessions and flags values that break the rules.
-- On the public sample many values are obfuscated by Google, so expect '<Other>' and '(data deleted)' rows.
-- Save the result as results/06_utm_audit.csv

WITH events AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source') AS source,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium') AS medium,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'campaign') AS campaign
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

sessions AS (
  SELECT
    CONCAT(user_pseudo_id, '.', CAST(ga_session_id AS STRING)) AS session_key,
    ARRAY_AGG(IF(source IS NOT NULL, STRUCT(source, medium, campaign), NULL) IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS t
  FROM events
  WHERE ga_session_id IS NOT NULL
  GROUP BY session_key
)

SELECT
  COALESCE(t.source, '(direct)') AS source,
  COALESCE(t.medium, '(none)') AS medium,
  COUNT(*) AS sessions,
  COUNT(DISTINCT t.campaign) AS distinct_campaigns,
  CASE
    WHEN t.source IS NULL OR t.source = '(direct)' THEN 'ok: direct'
    WHEN t.source IN ('<Other>', '(data deleted)') OR t.medium IN ('<Other>', '(data deleted)') THEN 'obfuscated in sample'
    WHEN REGEXP_CONTAINS(CONCAT(t.source, t.medium), r'[A-Z]') THEN 'fix: upper case'
    WHEN REGEXP_CONTAINS(CONCAT(t.source, t.medium), r'\s') THEN 'fix: contains spaces'
    WHEN t.medium NOT IN ('organic', 'referral', 'cpc', 'display', 'paid_social', 'social', 'email', 'affiliate') THEN 'fix: medium not in approved list'
    ELSE 'ok'
  END AS audit_flag
FROM sessions
GROUP BY source, medium, audit_flag
ORDER BY sessions DESC;
