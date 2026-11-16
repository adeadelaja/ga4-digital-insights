-- 04_attribution_first_vs_last.sql
-- Question: how much does the credit each channel gets for purchases change with the attribution model?
-- First touch      = the channel that first acquired the user (traffic_source, a user level field).
-- Last click       = the channel of the session the purchase happened in.
-- Last non direct  = the most recent non direct session channel for that user up to the purchase session
--                    (the logic behind GA4's paid and organic last click). The sample covers three months, so no
--                    lookback cap is applied.
-- Save the result as results/04_attribution_first_vs_last.csv

CREATE TEMP FUNCTION channel_group(source STRING, medium STRING) AS (
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
    traffic_source.source AS first_user_source,
    traffic_source.medium AS first_user_medium,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source') AS source,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium') AS medium,
    ecommerce.purchase_revenue_in_usd AS revenue_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

sessions AS (
  SELECT
    user_pseudo_id,
    CONCAT(user_pseudo_id, '.', CAST(ga_session_id AS STRING)) AS session_key,
    MIN(event_timestamp) AS session_start,
    ANY_VALUE(channel_group(first_user_source, first_user_medium)) AS first_touch_channel,
    ARRAY_AGG(IF(source IS NOT NULL, STRUCT(source, medium), NULL) IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS traffic,
    COUNTIF(event_name = 'purchase') AS purchases,
    SUM(IF(event_name = 'purchase', COALESCE(revenue_usd, 0), 0)) AS revenue_usd
  FROM events
  WHERE ga_session_id IS NOT NULL
  GROUP BY user_pseudo_id, session_key
),

sessions_with_paths AS (
  SELECT
    *,
    channel_group(traffic.source, traffic.medium) AS last_click_channel,
    COALESCE(
      LAST_VALUE(IF(channel_group(traffic.source, traffic.medium) != 'Direct', channel_group(traffic.source, traffic.medium), NULL) IGNORE NULLS)
        OVER (PARTITION BY user_pseudo_id ORDER BY session_start ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
      'Direct'
    ) AS last_non_direct_channel
  FROM sessions
),

purchase_sessions AS (
  SELECT * FROM sessions_with_paths WHERE purchases > 0
),

credit AS (
  SELECT 'first_touch' AS model, first_touch_channel AS channel, purchases, revenue_usd FROM purchase_sessions
  UNION ALL
  SELECT 'last_click', last_click_channel, purchases, revenue_usd FROM purchase_sessions
  UNION ALL
  SELECT 'last_non_direct', last_non_direct_channel, purchases, revenue_usd FROM purchase_sessions
),

pivoted AS (
  SELECT
    channel,
    SUM(IF(model = 'first_touch', purchases, 0)) AS purchases_first_touch,
    SUM(IF(model = 'last_click', purchases, 0)) AS purchases_last_click,
    SUM(IF(model = 'last_non_direct', purchases, 0)) AS purchases_last_non_direct,
    SUM(IF(model = 'first_touch', revenue_usd, 0)) AS revenue_first_touch,
    SUM(IF(model = 'last_click', revenue_usd, 0)) AS revenue_last_click,
    SUM(IF(model = 'last_non_direct', revenue_usd, 0)) AS revenue_last_non_direct
  FROM credit
  GROUP BY channel
)

SELECT
  channel,
  purchases_first_touch,
  purchases_last_click,
  purchases_last_non_direct,
  ROUND(revenue_first_touch, 2) AS revenue_first_touch_usd,
  ROUND(revenue_last_click, 2) AS revenue_last_click_usd,
  ROUND(revenue_last_non_direct, 2) AS revenue_last_non_direct_usd,
  ROUND(SAFE_DIVIDE(revenue_first_touch, SUM(revenue_first_touch) OVER ()), 4) AS share_first_touch,
  ROUND(SAFE_DIVIDE(revenue_last_click, SUM(revenue_last_click) OVER ()), 4) AS share_last_click,
  ROUND(SAFE_DIVIDE(revenue_last_non_direct, SUM(revenue_last_non_direct) OVER ()), 4) AS share_last_non_direct,
  ROUND(SAFE_DIVIDE(revenue_first_touch, SUM(revenue_first_touch) OVER ())
      - SAFE_DIVIDE(revenue_last_click, SUM(revenue_last_click) OVER ()), 4) AS share_change_first_vs_last_click
FROM pivoted
ORDER BY revenue_last_click_usd DESC;
