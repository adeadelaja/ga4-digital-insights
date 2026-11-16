-- 02_funnel_dropoff.sql
-- Question: where do sessions fall out of the purchase journey, and does it differ by device?
-- Closed funnel: a session counts at a step only if it also reached every earlier step in the same session.
-- Open funnel (sessions_open): sessions that fired the step's event at all, for comparison.
-- Save the result as results/02_funnel_dropoff.csv

WITH events AS (
  SELECT
    user_pseudo_id,
    event_name,
    device.category AS device_category,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

flags AS (
  SELECT
    CONCAT(user_pseudo_id, '.', CAST(ga_session_id AS STRING)) AS session_key,
    ANY_VALUE(device_category) AS device_category,
    MAX(IF(event_name = 'view_item', 1, 0)) AS viewed_item,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS added_to_cart,
    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS began_checkout,
    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS added_shipping,
    MAX(IF(event_name = 'add_payment_info', 1, 0)) AS added_payment,
    MAX(IF(event_name = 'purchase', 1, 0)) AS purchased
  FROM events
  WHERE ga_session_id IS NOT NULL
  GROUP BY session_key
),

counts AS (
  SELECT
    'All devices' AS device_category,
    COUNT(*) AS s1,
    SUM(viewed_item) AS c2,
    SUM(viewed_item * added_to_cart) AS c3,
    SUM(viewed_item * added_to_cart * began_checkout) AS c4,
    SUM(viewed_item * added_to_cart * began_checkout * added_shipping) AS c5,
    SUM(viewed_item * added_to_cart * began_checkout * added_shipping * added_payment) AS c6,
    SUM(viewed_item * added_to_cart * began_checkout * added_shipping * added_payment * purchased) AS c7,
    SUM(viewed_item) AS o2, SUM(added_to_cart) AS o3, SUM(began_checkout) AS o4,
    SUM(added_shipping) AS o5, SUM(added_payment) AS o6, SUM(purchased) AS o7
  FROM flags
  UNION ALL
  SELECT
    device_category,
    COUNT(*),
    SUM(viewed_item),
    SUM(viewed_item * added_to_cart),
    SUM(viewed_item * added_to_cart * began_checkout),
    SUM(viewed_item * added_to_cart * began_checkout * added_shipping),
    SUM(viewed_item * added_to_cart * began_checkout * added_shipping * added_payment),
    SUM(viewed_item * added_to_cart * began_checkout * added_shipping * added_payment * purchased),
    SUM(viewed_item), SUM(added_to_cart), SUM(began_checkout),
    SUM(added_shipping), SUM(added_payment), SUM(purchased)
  FROM flags
  GROUP BY device_category
),

steps AS (
  SELECT
    device_category,
    step.step_number,
    step.step_name,
    step.sessions_closed,
    step.sessions_open
  FROM counts,
  UNNEST([
    STRUCT(1 AS step_number, 'Session started' AS step_name, s1 AS sessions_closed, s1 AS sessions_open),
    STRUCT(2, 'Viewed an item', c2, o2),
    STRUCT(3, 'Added to cart', c3, o3),
    STRUCT(4, 'Began checkout', c4, o4),
    STRUCT(5, 'Added shipping', c5, o5),
    STRUCT(6, 'Added payment', c6, o6),
    STRUCT(7, 'Purchased', c7, o7)
  ]) AS step
)

SELECT
  device_category,
  step_number,
  step_name,
  sessions_closed,
  ROUND(SAFE_DIVIDE(sessions_closed, FIRST_VALUE(sessions_closed) OVER w), 4) AS share_of_sessions,
  ROUND(SAFE_DIVIDE(sessions_closed, LAG(sessions_closed) OVER w), 4) AS step_conversion,
  ROUND(1 - SAFE_DIVIDE(sessions_closed, LAG(sessions_closed) OVER w), 4) AS step_drop_off,
  LAG(sessions_closed) OVER w - sessions_closed AS sessions_lost_at_step,
  sessions_open
FROM steps
WINDOW w AS (PARTITION BY device_category ORDER BY step_number)
ORDER BY device_category = 'All devices' DESC, device_category, step_number;
