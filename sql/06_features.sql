-- sql/06_features.sql  (idempotent)
-- One row per user. Features use PRIOR orders only, to avoid leakage.

DROP TABLE IF EXISTS features.user_features;
CREATE TABLE features.user_features AS
WITH prior_orders AS (
    SELECT user_id, order_hour_of_day, gap_days, is_capped_gap, orders_from_end
    FROM analytics.user_order_timeline
    WHERE eval_set = 'prior'
),
gap_stats AS (
    SELECT
        user_id,
        COUNT(*)                                                       AS n_prior_orders,
        COUNT(gap_days)                                                AS n_gaps,
        SUM(gap_days)                                                  AS tenure_days_lb,   -- lower bound
        AVG(gap_days)                                                  AS mean_gap,         -- capped kept as 30
        percentile_cont(0.5) WITHIN GROUP (ORDER BY gap_days)          AS median_gap,       -- primary "typical gap"
        STDDEV_SAMP(gap_days)                                          AS sd_gap,
        AVG(gap_days) FILTER (WHERE NOT is_capped_gap)                 AS mean_gap_uncapped, -- sensitivity view
        COUNT(*) FILTER (WHERE is_capped_gap)                          AS n_capped_gaps,
        COUNT(*) FILTER (WHERE gap_days = 0)                           AS n_same_day_gaps,
        AVG(gap_days) FILTER (WHERE orders_from_end BETWEEN 2 AND 4)   AS recent_mean_gap, -- last 3 prior orders
        MAX(gap_days) FILTER (WHERE orders_from_end = 2)               AS last_prior_gap,
        AVG(order_hour_of_day)                                         AS avg_order_hour
    FROM prior_orders
    GROUP BY user_id
),
basket_stats AS (
    SELECT
        o.user_id,
        COUNT(*)                        AS total_items,
        SUM(op.reordered)               AS reordered_items,
        COUNT(DISTINCT op.product_id)   AS distinct_products
    FROM raw.order_products_prior op
    JOIN raw.orders o ON o.order_id = op.order_id
    GROUP BY o.user_id
)
SELECT
    g.user_id,
    -- frequency and tenure
    g.n_prior_orders,
    g.n_gaps,
    g.tenure_days_lb,
    -- personal rhythm
    ROUND(g.mean_gap::numeric, 2)                                   AS mean_gap,
    ROUND(g.median_gap::numeric, 2)                                 AS median_gap,
    ROUND(g.sd_gap::numeric, 2)                                     AS sd_gap,
    ROUND(g.mean_gap_uncapped::numeric, 2)                          AS mean_gap_uncapped,
    -- censoring diagnostics
    g.n_capped_gaps,
    ROUND(g.n_capped_gaps::numeric / NULLIF(g.n_gaps, 0), 3)        AS pct_capped_gaps,
    (g.n_capped_gaps::numeric / NULLIF(g.n_gaps, 0) >= 0.5)         AS is_censored_heavy,
    g.n_same_day_gaps,
    -- recency and trend
    g.last_prior_gap,
    ROUND(g.recent_mean_gap::numeric, 2)                            AS recent_mean_gap,
    ROUND((g.recent_mean_gap - g.mean_gap)::numeric, 2)             AS gap_trend,   -- > 0 = slowing down
    -- basket behavior
    ROUND(b.total_items::numeric / g.n_prior_orders, 2)             AS avg_basket_size,
    ROUND(b.reordered_items::numeric / b.total_items, 3)            AS reorder_ratio,
    b.distinct_products,
    ROUND(b.distinct_products::numeric / b.total_items, 3)          AS variety_ratio,
    ROUND(g.avg_order_hour::numeric, 1)                             AS avg_order_hour,
    -- data limitation flag
    (g.n_prior_orders = 99)                                         AS is_truncated_history
FROM gap_stats g
JOIN basket_stats b USING (user_id);

ALTER TABLE features.user_features ADD PRIMARY KEY (user_id);

-- The holdout order (each user's last): kept SEPARATE from features
DROP TABLE IF EXISTS features.user_holdout;
CREATE TABLE features.user_holdout AS
SELECT
    user_id,
    order_id          AS holdout_order_id,
    eval_set,
    gap_days          AS holdout_gap_days,
    is_capped_gap     AS holdout_is_capped
FROM analytics.user_order_timeline
WHERE orders_from_end = 1;

ALTER TABLE features.user_holdout ADD PRIMARY KEY (user_id);

ANALYZE features.user_features;
ANALYZE features.user_holdout;