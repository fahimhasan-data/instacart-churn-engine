# DAX Measures Reference

Power BI model: `fact_user` (one row per user, 206,209 rows) with three dimension tables:
`dim_risk_tier`, `dim_tenure_band`, `dim_rhythm_class`. Every dimension relates to `fact_user`
on its own name column (many-to-one, single direction).

The target behind every rate is `late_return_30d`: 1 if the user's next order came 30 or more days
after the previous one, otherwise 0.

## Core measures

```DAX
Users = DISTINCTCOUNT(fact_user[user_id])
```
Number of distinct customers in the current filter.

```DAX
Late Returns = SUM(fact_user[late_return_30d])
```
Customers whose next order took 30+ days. Works because the column is 0/1.

```DAX
Late Return Rate = DIVIDE([Late Returns], [Users])
```
Share of customers who returned late. `DIVIDE` returns blank instead of an error if there are no users.

```DAX
Avg Risk Score = AVERAGE(fact_user[risk_score])
```
Average predicted probability of a late return (out-of-fold scores from the gradient boosting model).

```DAX
Calibration Gap = [Avg Risk Score] - [Late Return Rate]
```
Predicted minus actual. Close to zero means the probabilities can be trusted.

```DAX
Overall Late Rate = CALCULATE([Late Return Rate], REMOVEFILTERS())
```
Whole-population late rate (30.6%), ignoring every slicer. Used for KPI cards.

```DAX
Selection Late Rate = CALCULATE([Late Return Rate], ALLSELECTED())
```
Late rate of whatever the viewer has selected with slicers. Used as the benchmark for lift.

```DAX
Lift = DIVIDE([Late Return Rate], [Selection Late Rate])
```
How many times riskier a group is than the current selection.

```DAX
Share of Late Returns =
DIVIDE([Late Returns], CALCULATE([Late Returns], ALLSELECTED()))
```
Share of all late returns in the current selection that fall in this group.

```DAX
Grain Check = COUNTROWS(fact_user) - DISTINCTCOUNT(fact_user[user_id])
```
Must always be 0. A non-zero value means a user appears twice and every rate is distorted.

## Campaign planner (what-if)

`Contact Share` is a what-if parameter (0.1 to 0.5, step 0.1, default 0.2). Power BI creates the
`Contact Share Value` measure automatically. `risk_decile = 1` is the riskiest 10% of users.

```DAX
Contacted Users =
VAR maxDecile = ROUND([Contact Share Value] * 10, 0)
RETURN CALCULATE([Users], fact_user[risk_decile] <= maxDecile)
```

```DAX
Late Returns Reached =
VAR maxDecile = ROUND([Contact Share Value] * 10, 0)
RETURN CALCULATE([Late Returns], fact_user[risk_decile] <= maxDecile)
```

```DAX
Campaign Precision = DIVIDE([Late Returns Reached], [Contacted Users])
```
Of the customers contacted, the share who really would have returned late.

```DAX
Campaign Recall =
DIVIDE([Late Returns Reached], CALCULATE([Late Returns], ALLSELECTED()))
```
Of all late returns, the share reached by the campaign.

```DAX
Campaign Lift = DIVIDE([Campaign Precision], [Selection Late Rate])
```
How much better the campaign targets late returners than contacting customers at random.

## Chart helper measures

```DAX
Cumulative Capture =
VAR d = MAX(fact_user[risk_decile])
RETURN DIVIDE(
    CALCULATE([Late Returns], FILTER(ALL(fact_user[risk_decile]), fact_user[risk_decile] <= d)),
    CALCULATE([Late Returns], ALL(fact_user[risk_decile])))
```
Share of all late returns found in the riskiest `d` deciles. Used on the gains chart.

```DAX
Random Capture = MAX(fact_user[risk_decile]) / 10
```
What contacting customers at random would capture. The diagonal baseline on the gains chart.

## Reference values (full population, no slicers)

| Check | Expected |
|---|---|
| Users | 206,209 |
| Late Return Rate | 30.6% |
| Grain Check | 0 |
| High tier: users / avg score / late rate | 41,241 / 0.580 / 57.9% |
| Medium tier | 61,863 / 0.409 / 41.0% |
| Low tier | 103,105 / 0.136 / 13.5% |
| Contact Share 0.2: precision / recall / lift | 0.579 / 0.378 / 1.89 |
| Contact Share 0.1: precision / recall / lift | 0.621 / 0.203 / 2.03 |
