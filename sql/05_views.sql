-- sql/05_views.sql  (idempotent)

-- 1. Unified basket view: prior + train in one place
DROP VIEW IF EXISTS analytics.order_products CASCADE;
CREATE VIEW analytics.order_products AS
SELECT order_id, product_id, add_to_cart_order, reordered, 'prior'::text AS source_set
FROM raw.order_products_prior
UNION ALL
SELECT order_id, product_id, add_to_cart_order, reordered, 'train'::text AS source_set
FROM raw.order_products_train;

-- 2. Per-order user timeline with window functions
DROP MATERIALIZED VIEW IF EXISTS analytics.user_order_timeline;
CREATE MATERIALIZED VIEW analytics.user_order_timeline AS
SELECT
    o.order_id,
    o.user_id,
    o.eval_set,
    o.order_number,
    o.order_dow,
    o.order_hour_of_day,
    o.days_since_prior_order                          AS gap_days,
    COALESCE(o.days_since_prior_order = 30, FALSE)    AS is_capped_gap,
    -- lower bound on elapsed days, because capped gaps hide time
    SUM(COALESCE(o.days_since_prior_order, 0)) OVER (
        PARTITION BY o.user_id ORDER BY o.order_number
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                 AS days_since_first_order,
    LAG(o.days_since_prior_order) OVER (
        PARTITION BY o.user_id ORDER BY o.order_number
    )                                                 AS prev_gap_days,
    COUNT(*) OVER (PARTITION BY o.user_id)            AS user_total_orders,
    ROW_NUMBER() OVER (
        PARTITION BY o.user_id ORDER BY o.order_number DESC
    )                                                 AS orders_from_end   -- 1 = the holdout (train/test) order
FROM raw.orders o;

CREATE UNIQUE INDEX idx_timeline_order ON analytics.user_order_timeline (order_id);
CREATE INDEX idx_timeline_user_num ON analytics.user_order_timeline (user_id, order_number);
ANALYZE analytics.user_order_timeline;



-- A. Unified view row count: expect 33,819,106 (32,434,489 + 1,384,617)
SELECT COUNT(*) FROM analytics.order_products;

-- B. No overlap: prior baskets belong only to 'prior' orders, train baskets only to 'train'
SELECT o.eval_set, op.source_set, COUNT(DISTINCT op.order_id) AS orders
FROM analytics.order_products op
JOIN raw.orders o USING (order_id)
GROUP BY 1, 2;

-- C. Timeline row count: expect 3,421,083
SELECT COUNT(*) FROM analytics.user_order_timeline;

-- D. Exactly one holdout order per user: expect 206,209 and 0
SELECT COUNT(*) FILTER (WHERE orders_from_end = 1)                          AS last_orders,
       COUNT(*) FILTER (WHERE orders_from_end = 1 AND eval_set = 'prior')   AS last_order_is_prior
FROM analytics.user_order_timeline;

-- E. Spot-check one user against the raw data
SELECT order_number, eval_set, gap_days, is_capped_gap,
       days_since_first_order, prev_gap_days, orders_from_end
FROM analytics.user_order_timeline
WHERE user_id = 1
ORDER BY order_number;


--capped-gap decision
SELECT
    COUNT(*)                                                        AS users,
    COUNT(*) FILTER (WHERE capped = 0)                              AS no_capped_gaps,
    COUNT(*) FILTER (WHERE capped > 0 AND capped::numeric / gaps < 0.5) AS some_capped,
    COUNT(*) FILTER (WHERE capped::numeric / gaps >= 0.5)           AS mostly_capped
FROM (
    SELECT user_id,
           COUNT(gap_days)                          AS gaps,
           COUNT(*) FILTER (WHERE is_capped_gap)    AS capped
    FROM analytics.user_order_timeline
    WHERE eval_set = 'prior'
    GROUP BY user_id
) t;