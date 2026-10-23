ALTER TABLE features.user_scores ADD PRIMARY KEY (user_id);

SELECT risk_tier,
       COUNT(*)                                          AS users,
       ROUND(AVG(risk_score)::numeric, 3)                AS avg_score,
       ROUND(AVG(target_capped_holdout)::numeric, 3)     AS actual_capped_rate
FROM features.user_scores
GROUP BY risk_tier
ORDER BY avg_score DESC;

SELECT COUNT(*) AS users, ROUND(AVG(risk_score)::numeric, 3) AS avg_score
FROM features.user_scores;