-- sql/04_data_quality.sql

-- CHECK 1: Order counts by eval_set, plus distinct users
SELECT eval_set, COUNT(*) AS orders, COUNT(DISTINCT user_id) AS users
FROM raw.orders
GROUP BY eval_set
ORDER BY eval_set;

-- CHECK 2: Value ranges (any surprises here break later logic)
SELECT
    MIN(order_number)            AS min_order_num,
    MAX(order_number)            AS max_order_num,
    MIN(order_dow)               AS min_dow,
    MAX(order_dow)               AS max_dow,
    MIN(order_hour_of_day)       AS min_hour,
    MAX(order_hour_of_day)       AS max_hour,
    MIN(days_since_prior_order)  AS min_gap,
    MAX(days_since_prior_order)  AS max_gap
FROM raw.orders;

-- CHECK 3: NULL gaps should occur ONLY on each user's first order
SELECT
    COUNT(*) FILTER (WHERE days_since_prior_order IS NULL AND order_number = 1) AS null_on_first,
    COUNT(*) FILTER (WHERE days_since_prior_order IS NULL AND order_number > 1) AS null_unexpected,
    COUNT(*) FILTER (WHERE days_since_prior_order IS NOT NULL AND order_number = 1) AS value_on_first
FROM raw.orders;

-- CHECK 4: Is every user's order sequence contiguous (1..N, no gaps)?
SELECT COUNT(*) AS users_with_broken_sequence
FROM (
    SELECT user_id
    FROM raw.orders
    GROUP BY user_id
    HAVING MAX(order_number) <> COUNT(*)
       OR  MIN(order_number) <> 1
) t;

-- CHECK 5: Which orders have NO product rows, by eval_set?
SELECT o.eval_set, COUNT(*) AS orders_without_products
FROM raw.orders o
WHERE NOT EXISTS (SELECT 1 FROM raw.order_products_prior p WHERE p.order_id = o.order_id)
  AND NOT EXISTS (SELECT 1 FROM raw.order_products_train t WHERE t.order_id = o.order_id)
GROUP BY o.eval_set
ORDER BY o.eval_set;

-- CHECK 6: How heavily does the 30-day cap affect the data?
SELECT
    COUNT(*) FILTER (WHERE days_since_prior_order = 30) AS orders_at_cap,
    COUNT(*) FILTER (WHERE days_since_prior_order IS NOT NULL) AS orders_with_gap,
    ROUND(100.0 * COUNT(*) FILTER (WHERE days_since_prior_order = 30)
          / COUNT(*) FILTER (WHERE days_since_prior_order IS NOT NULL), 2) AS pct_at_cap
FROM raw.orders;

-- CHECK 7: How many users hit the 100-order ceiling?
SELECT COUNT(*) AS users_at_100_orders
FROM (SELECT user_id FROM raw.orders GROUP BY user_id HAVING MAX(order_number) = 100) t;