-- 03_landing_pages.sql
-- Question: which landing pages carry the most sessions, and which ones underperform the site?
-- Landing page = the first page_view in the session, query string removed.
-- missed_conversions_vs_site = extra converting sessions the page would have produced at the site's average conversion rate.
-- Save the result as results/03_landing_pages.csv

WITH events AS (
  SELECT
    user_pseudo_id,
    event_name,
    event_timestamp,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS page_location,
    (SELECT COALESCE(value.string_value, CAST(value.int_value AS STRING)) FROM UNNEST(event_params) WHERE key = 'session_engaged') AS session_engaged,
    ecommerce.purchase_revenue_in_usd AS revenue_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

sessions AS (
  SELECT
    CONCAT(user_pseudo_id, '.', CAST(ga_session_id AS STRING)) AS session_key,
    ARRAY_AGG(IF(event_name = 'page_view', page_location, NULL) IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS landing_url,
    MAX(IF(session_engaged = '1', 1, 0)) AS engaged,
    MAX(IF(event_name = 'purchase', 1, 0)) AS converted,
    SUM(IF(event_name = 'purchase', COALESCE(revenue_usd, 0), 0)) AS revenue_usd
  FROM events
  WHERE ga_session_id IS NOT NULL
  GROUP BY session_key
),

pages AS (
  SELECT
    COALESCE(REGEXP_REPLACE(REGEXP_REPLACE(landing_url, r'[?#].*$', ''), r'^https?://[^/]+', ''), '(no page_view)') AS landing_page,
    COUNT(*) AS sessions,
    SUM(engaged) AS engaged_sessions,
    SUM(converted) AS converting_sessions,
    SUM(revenue_usd) AS revenue_usd
  FROM sessions
  GROUP BY landing_page
),

site AS (
  SELECT SAFE_DIVIDE(SUM(converting_sessions), SUM(sessions)) AS site_conversion_rate
  FROM pages
)

SELECT
  landing_page,
  sessions,
  ROUND(SAFE_DIVIDE(engaged_sessions, sessions), 4) AS engagement_rate,
  ROUND(1 - SAFE_DIVIDE(engaged_sessions, sessions), 4) AS bounce_rate,
  converting_sessions,
  ROUND(SAFE_DIVIDE(converting_sessions, sessions), 4) AS session_conversion_rate,
  ROUND(site.site_conversion_rate, 4) AS site_conversion_rate,
  ROUND(GREATEST(sessions * site.site_conversion_rate - converting_sessions, 0), 0) AS missed_conversions_vs_site,
  ROUND(revenue_usd, 2) AS revenue_usd,
  ROUND(SAFE_DIVIDE(revenue_usd, sessions), 2) AS revenue_per_session_usd
FROM pages
CROSS JOIN site
WHERE sessions >= 500
ORDER BY sessions DESC
LIMIT 25;
