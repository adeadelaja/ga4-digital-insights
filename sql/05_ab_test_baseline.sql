-- 05_ab_test_baseline.sql
-- Question: what baseline rates and weekly traffic should the A/B test be sized on?
-- Two candidate tests, both taken from the funnel:
--   product page test: sessions that viewed an item  -> added to cart
--   cart test:         sessions that added to cart   -> began checkout
-- Output: one row per ISO week plus an 'Overall' row. Feed the Overall row into experimentation/sample_size.py.
-- Save the result as results/05_ab_test_baseline.csv

WITH events AS (
  SELECT
    user_pseudo_id,
    event_name,
    PARSE_DATE('%Y%m%d', event_date) AS day,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

flags AS (
  SELECT
    CONCAT(user_pseudo_id, '.', CAST(ga_session_id AS STRING)) AS session_key,
    MIN(day) AS session_day,
    MAX(IF(event_name = 'view_item', 1, 0)) AS viewed_item,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS added_to_cart,
    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS began_checkout
  FROM events
  WHERE ga_session_id IS NOT NULL
  GROUP BY session_key
),

weekly AS (
  SELECT
    FORMAT_DATE('%G W%V', DATE_TRUNC(session_day, ISOWEEK)) AS period,
    DATE_TRUNC(session_day, ISOWEEK) AS week_start,
    SUM(viewed_item) AS sessions_viewed_item,
    SUM(viewed_item * added_to_cart) AS sessions_viewed_and_added,
    SUM(added_to_cart) AS sessions_added_to_cart,
    SUM(added_to_cart * began_checkout) AS sessions_added_and_checked_out
  FROM flags
  GROUP BY period, week_start
),

full_weeks AS (
  -- drop the part weeks at either end of the sample so weekly averages are fair
  SELECT * FROM weekly
  WHERE week_start BETWEEN DATE '2020-11-02' AND DATE '2021-01-25'
)

SELECT
  period,
  sessions_viewed_item,
  ROUND(SAFE_DIVIDE(sessions_viewed_and_added, sessions_viewed_item), 4) AS view_to_cart_rate,
  sessions_added_to_cart,
  ROUND(SAFE_DIVIDE(sessions_added_and_checked_out, sessions_added_to_cart), 4) AS cart_to_checkout_rate
FROM (
  SELECT period, week_start, sessions_viewed_item, sessions_viewed_and_added, sessions_added_to_cart, sessions_added_and_checked_out, 0 AS sort_key
  FROM full_weeks
  UNION ALL
  SELECT
    'Overall (weekly average)',
    NULL,
    CAST(ROUND(AVG(sessions_viewed_item)) AS INT64),
    CAST(ROUND(AVG(sessions_viewed_and_added)) AS INT64),
    CAST(ROUND(AVG(sessions_added_to_cart)) AS INT64),
    CAST(ROUND(AVG(sessions_added_and_checked_out)) AS INT64),
    1
  FROM full_weeks
)
ORDER BY sort_key, week_start;
