# Decisions Log

Every design choice made during the project, with the evidence behind it.

| # | Decision | Rationale |
|---|---|---|
| 1 | Layered schemas: `raw`, `analytics`, `features` (and later `reporting`) | Separates ingestion, cleaning, modeling, and presentation. Raw data is never edited |
| 2 | Add constraints and indexes after the bulk load | Loading 34M rows into constrained tables is much slower; constraint creation also tests key integrity |
| 3 | Treat `days_since_prior_order = 30` as right-censored ("30+ days") | 11.49% of gaps (369,323 of 3,214,874) equal 30. A 31-day and a 90-day gap look identical. Flagged as `is_capped_gap`; sensitivity analysis in Phase 2 |
| 4 | Keep NULL `days_since_prior_order` as NULL | Exactly 206,209 NULLs, one per user's first order. A structural NULL, not missing data |
| 5 | Exclude `test` orders from basket-level analysis | All 75,000 `test` orders have no product rows. They remain usable for order-level features |
| 6 | Unify prior and train baskets in a view with a `source_set` column, using `UNION ALL` | Keeps raw tables untouched. The sets cannot overlap, so deduplication would only cost time |
| 7 | Treat `order_number = 100` as a truncation ceiling | 1,374 users (about 0.67%) have exactly 100 orders, so their counts are lower bounds |
| 8 | Median gap is the primary "typical gap"; mean, SD, and an uncapped mean are secondary | 20% of users have at least 50% capped gaps. The median is robust to censoring below 50% |
| 9 | Build features from prior orders only; store each user's holdout order separately | Prevents leakage. No user is observed fully churning |
| 10 | Segment users into `regular`, `mostly_capped`, `all_capped`, `constant_gap` | `all_capped` users (4.3%) have no measurable rhythm, and 36.6% still returned in under 30 days. `constant_gap` users are mostly 2-gap coincidences |
| 11 | Require at least 5 prior gaps for personal z-scores; floor the SD at 1 day | 71% of users qualify. Personal SDs from fewer gaps are mostly noise. Gaps are whole days |
| 12 | Label holdout orders late / on time / unknown, not binary | About 31% of holdout gaps are capped at 30. A capped holdout below the cut-off could still be late |
| 13 | Provisional late-return rule: z >= 2 on eligible users; sensitivity at 1.5 | The on-time share is stable (66-75%) across cut-offs; the cut-off mostly splits capped users |
| 14 | Report the final-gap slowdown as a "signal", not as churn | Holdout gaps are capped more often than a user's own history in every tenure band (+4.8 to +9.5 points). Post-holdout behavior is not observed |
| 15 | Treat z >= 2 as a screening rule, not a 2.3% tail | Empirical tail is 9.0% (skew 1.95, excess kurtosis 36). The tail grows with history, so it is not small-sample noise |
| 16 | Report late-return prevalence as definition-dependent | 9% (z >= 2), 23% (median ratio >= 2), up to 32% with capped gaps excluded. Rules agree on about 85% of users |
| 17 | Do not use z >= 2 alone as a churn label | Placebo test: the same rule flags 8.1% of users on an ordinary earlier gap versus 9.2% on the final gap. Capped-gap rates differ more (18.4% versus 22.4%) |
| 18 | Use "capped holdout if last prior gap was capped" as the naive baseline | Capped gaps persist within users (42% versus 18%), so a trivial rule already carries signal |
| 19 | Phase 3 target is the holdout gap capped at 30 days, defined for all 206,209 users | Observed (30.6% base rate), threshold-free, and covers the roughly 29% of users without a reliable personal rhythm |
| 20 | Model inputs come only from `features.user_features`; an assertion blocks holdout-derived columns | Prevents leakage by construction. Stratified random 80/20 split by user, since no real dates exist |
| 21 | Benchmarks to beat: ROC-AUC 0.685 and PR-AUC 0.458 | The naive rule scored with `last_prior_gap`. Majority rule gets 69.4% accuracy with 0% recall, so accuracy is not the headline metric |
| 22 | Logistic regression drops `n_gaps` and `gap_trend`, imputes `mean_gap_uncapped` with a missing flag | Exact collinearity; informative missingness (8,797 users); fit inside a pipeline to avoid leakage |
| 23 | Logistic result: test ROC-AUC 0.754, PR-AUC 0.537 | Clear ranking gain, about 3 points at equal alert volume. Correlated gap features share coefficients, so interpret groups |
| 24 | Gradient boosting: test ROC-AUC 0.765, PR-AUC 0.549 | Beats logistic by about 0.011; the signal is largely linear |
| 25 | Probabilities are well calibrated (Brier 0.174 versus 0.213 baseline) | Scores can be shown as probabilities in Power BI without recalibration |
| 26 | Scoring model is gradient boosting; logistic regression is kept as the benchmark | Wins every comparison, finds a near-certain-return group, and batch scoring removes its deployment cost |
| 27 | Report grouped permutation importance for correlated features | Shuffling the gap family together drops PR-AUC by 0.154, versus 0.099 summed from single features |
| 28 | Scores are 5-fold out-of-fold; tiers are High (top 20%), Medium (next 30%), Low (bottom 50%) | Each user is scored by a model that never saw them. Predicted versus actual by tier: 0.580/0.579, 0.409/0.410, 0.136/0.135 |
| 29 | Power BI reads from `reporting` views in a star schema, with a `Grain Check` measure | One row per user is the grain; duplicates would silently distort every rate. Sort columns fix category ordering |
| 30 | Lift and recall benchmark against the current slicer selection (`ALLSELECTED`) | Prevents a segment's own risk from being mistaken for model skill. Whole-population KPIs use `REMOVEFILTERS` |
| 31 | The `.pbix` is not committed; DAX is documented in `docs/dax_measures.md` | Binary files do not diff, and the file embeds all the data |
