-- sql/09_reporting.sql  (idempotent)
CREATE SCHEMA IF NOT EXISTS reporting;

DROP VIEW IF EXISTS reporting.fact_user;
CREATE VIEW reporting.fact_user AS
SELECT
    s.user_id,
    s.risk_score,
    s.risk_decile,
    s.risk_tier,
    s.target_capped_holdout        AS late_return_30d,
    h.holdout_gap_days,
    s.rhythm_class,
    s.label_z2,
    CASE WHEN s.n_prior_orders < 5  THEN '3-4'
         WHEN s.n_prior_orders < 10 THEN '5-9'
         WHEN s.n_prior_orders < 20 THEN '10-19'
         ELSE '20+' END            AS tenure_band,
    s.n_prior_orders,
    s.mean_gap, s.median_gap, s.recent_mean_gap, s.last_prior_gap,
    s.avg_basket_size, s.reorder_ratio,
    f.pct_capped_gaps
FROM features.user_scores   s
JOIN features.user_features f USING (user_id)
JOIN features.user_holdout  h USING (user_id);

-- Small dimension tables: give categories a sort order for the dashboard
DROP VIEW IF EXISTS reporting.dim_risk_tier;
CREATE VIEW reporting.dim_risk_tier AS
SELECT * FROM (VALUES ('High', 1), ('Medium', 2), ('Low', 3)) AS t(risk_tier, tier_sort);

DROP VIEW IF EXISTS reporting.dim_tenure_band;
CREATE VIEW reporting.dim_tenure_band AS
SELECT * FROM (VALUES ('3-4', 1), ('5-9', 2), ('10-19', 3), ('20+', 4)) AS t(tenure_band, band_sort);

DROP VIEW IF EXISTS reporting.dim_rhythm_class;
CREATE VIEW reporting.dim_rhythm_class AS
SELECT * FROM (VALUES ('regular', 1), ('mostly_capped', 2), ('constant_gap', 3), ('all_capped', 4))
       AS t(rhythm_class, class_sort);

--Verification
SELECT COUNT(*) AS users,
       ROUND(AVG(risk_score)::numeric, 3)      AS avg_score,
       ROUND(AVG(late_return_30d)::numeric, 3) AS late_rate
FROM reporting.fact_user;