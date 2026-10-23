ALTER TABLE features.user_labels ADD PRIMARY KEY (user_id);

SELECT COUNT(*) AS users,
       SUM(target_capped_holdout) AS capped,
       ROUND(AVG(target_capped_holdout), 3) AS capped_rate,
       COUNT(*) FILTER (WHERE label_z2 = 'late') AS late_z2,
       COUNT(*) FILTER (WHERE label_z2 = 'not_eligible') AS not_eligible
FROM features.user_labels;