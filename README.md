# Customer Re-Engagement & Churn Prevention Engine
### Optimizing Retention and Reorder Timing for E-Grocery (Instacart Market Basket Data)

> **Status:** Phase 1 complete | Phase 2 - in progress

## 1. Business Problem

An e-grocery business doesn't lose customers loudly. They just stop ordering. A fixed rule like "no order in 30 days = churned" is wrong for most customers: a weekly shopper who goes quiet for 21 days is in trouble, while a monthly shopper who goes quiet for 21 days is perfectly normal.

**This project answers three questions:**
1. How do we define "at risk" *per customer*, relative to their own reorder rhythm?
2. Do customers who cross that personal threshold actually behave differently (statistically)?
3. Can we predict who will churn or reorder next, and show the business where to act?

## 2. Dataset

[Instacart Market Basket Analysis (Kaggle)](https://www.kaggle.com/datasets/psparks/instacart-market-basket-analysis)

| File | Grain (one row = ...) | Approx. rows | Key columns |
|---|---|---|---|
| `aisles.csv` | an aisle | 134 | `aisle_id`, `aisle` |
| `departments.csv` | a department | 21 | `department_id`, `department` |
| `products.csv` | a product | 49,688 | `product_id`, `product_name`, `aisle_id`, `department_id` |
| `orders.csv` | an order | 3.4M | `order_id`, `user_id`, `eval_set`, `order_number`, `order_dow`, `order_hour_of_day`, `days_since_prior_order` |
| `order_products__prior.csv` | a product within a prior order | 32.4M | `order_id`, `product_id`, `add_to_cart_order`, `reordered` |
| `order_products__train.csv` | a product within a train order | 1.4M | same as above |

### Dataset gotchas (read these before writing any query)
- **No real dates.** The only time axis is `days_since_prior_order` and `order_number`. Any "date" has to be *derived* by cumulative sum per user.
- **`days_since_prior_order` is NULL on each user's first order** (there is no prior order) and appears **capped at 30**. Our "churn" thresholds must respect that cap.
- **`eval_set` is `prior`, `train`, or `test`.** Each user's *last* order is labeled `train` or `test`; all earlier orders are `prior`.
- **`test` orders have no product rows** (labels were hidden for the original competition). Order-level analysis can use them; basket-level analysis cannot.
- Product rows for `prior` and `train` orders live in **two separate tables**. We will need to unify them deliberately.

## 3. Project Roadmap

| Phase | Focus | Tools | Deliverable |
|---|---|---|---|
| **1** | Database setup, relational modeling, advanced SQL feature engineering | PostgreSQL | Clean schema + `features.user_features` table |
| **2** | Hypothesis testing and personalised churn thresholds (z-scores) | Pandas, SciPy, Statsmodels | Statistical evidence + per-user risk flag |
| **3** | Churn/reorder prediction model | Scikit-Learn | Validated, explainable classifier |
| **4** | Executive dashboard | Power BI, DAX | Interactive retention dashboard |

## 4. Repository Structure

```
instacart-churn-engine/
|-- README.md
|-- data/
|   |-- raw/                  # Kaggle CSVs (git-ignored, too large)
|-- sql/
|   |-- 01_schema.sql         # DDL
|   |-- 02_load.sql           # COPY commands
|   |-- 03_constraints.sql    # PKs, FKs, indexes (after load)
|   |-- 04_data_quality.sql   # validation checks
|   |-- 05_views.sql          # unified order-product view, user order timeline
|   |-- 06_features.sql       # feature engineering
|-- notebooks/                # Phase 2 and 3
|-- powerbi/                  # Phase 4 (.pbix + screenshots)
|-- docs/                     # ERD, data dictionary, decisions log
|-- .gitignore                # must include data/raw/
```

## 5. Phase 1 Overview: Database, Modeling, and SQL Feature Engineering

**Goal:** turn six flat CSVs into a trustworthy relational model, then build a one-row-per-customer feature table that Phases 2 and 3 will consume.

### Design principles we'll follow
1. **Layered schemas.** `raw` (exact CSV copy), `analytics` (cleaned views), `features` (model-ready tables). Raw data is never edited.
2. **Load first, constrain after.** Bulk-loading 32M rows is much faster without PKs/FKs/indexes; we add them afterwards.
3. **Validate before trusting.** Row counts, orphan keys, NULL checks, and duplicate checks are part of the deliverable, not an afterthought.
4. **Every SQL file is re-runnable** (idempotent) and committed to Git.

### Phase 1 steps

| Step | What we do | Skills shown |
|---|---|---|
| **1.1** | Create database, schemas, and raw table DDL | DDL, data typing |
| **1.2** | Bulk load CSVs and verify row counts | `COPY`/`\copy`, validation |
| **1.3** | Add PKs, FKs, indexes; draw the ERD | Relational modeling, indexing |
| **1.4** | Data quality audit (orphans, NULLs, duplicates, cap at 30) | Defensive SQL |
| **1.5** | Build unified `order_products` view and per-user order timeline | `UNION ALL`, window functions (`SUM() OVER`, `LAG`) |
| **1.6** | Engineer the `features.user_features` table (recency, frequency, interval stats, basket behavior, reorder ratio) | CTEs, aggregations, window functions |

---

## 6. Step 1.1: Create the Database, Schemas, and Raw Tables

### Task
Create a database called `instacart`, three schemas, and the six raw tables. Save the DDL as `sql/01_schema.sql`.

### Run this first (as a superuser such as `postgres`)

```sql
CREATE DATABASE instacart;
```

Then connect to the new database (`\c instacart` in psql, or open a new connection in pgAdmin/DBeaver) and run:

```sql
-- sql/01_schema.sql
CREATE SCHEMA IF NOT EXISTS raw;        -- untouched copy of the CSVs
CREATE SCHEMA IF NOT EXISTS analytics;  -- cleaned views and models
CREATE SCHEMA IF NOT EXISTS features;   -- model-ready feature tables

DROP TABLE IF EXISTS raw.order_products_train;
DROP TABLE IF EXISTS raw.order_products_prior;
DROP TABLE IF EXISTS raw.orders;
DROP TABLE IF EXISTS raw.products;
DROP TABLE IF EXISTS raw.departments;
DROP TABLE IF EXISTS raw.aisles;

CREATE TABLE raw.aisles (
    aisle_id    INTEGER,
    aisle       TEXT
);

CREATE TABLE raw.departments (
    department_id INTEGER,
    department    TEXT
);

CREATE TABLE raw.products (
    product_id    INTEGER,
    product_name  TEXT,
    aisle_id      INTEGER,
    department_id INTEGER
);

CREATE TABLE raw.orders (
    order_id                INTEGER,
    user_id                 INTEGER,
    eval_set                TEXT,
    order_number            SMALLINT,
    order_dow               SMALLINT,
    order_hour_of_day       SMALLINT,
    days_since_prior_order  NUMERIC(4,1)   -- NULL on a user's first order
);

CREATE TABLE raw.order_products_prior (
    order_id            INTEGER,
    product_id          INTEGER,
    add_to_cart_order   SMALLINT,
    reordered           SMALLINT
);

CREATE TABLE raw.order_products_train (
    order_id            INTEGER,
    product_id          INTEGER,
    add_to_cart_order   SMALLINT,
    reordered           SMALLINT
);
```

### Verify
```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('raw', 'analytics', 'features')
ORDER BY 1, 2;
```
You should see six tables in `raw` and nothing yet in the other two schemas.

### Why we wrote it this way (be ready to explain in interviews)
- **No constraints yet.** Loading ~34M rows into tables with PKs/FKs/indexes is far slower. We add them in Step 1.3.
- **`SMALLINT` for small ranges.** `order_dow` (0-6), `order_hour_of_day` (0-23), `reordered` (0/1) don't need 4 bytes each. On 32M rows, that saves real space.
- **`NUMERIC(4,1)` for `days_since_prior_order`.** The CSV stores values like `8.0`; the range is 0-30. Numeric avoids float rounding in later calculations.
- **`raw` is a landing zone.** We never edit it. Every fix happens downstream, so the pipeline is auditable.

### Your checkpoint
Before Step 1.2, share:
1. Output of the verification query above.
2. Any errors you hit.

---

## 7. Decisions Log (we'll keep adding to this)

| # | Decision | Rationale |
|---|---|---|
| 1 | Three-layer schema (`raw` / `analytics` / `features`) | Separates ingestion, cleaning, and modeling; mirrors production practice |
| 2 | Constraints added after bulk load | Load performance |
| 3 | Treat `days_since_prior_order = 30` as right-censored ("30+ days"), not a real measurement | 11.49% of gaps (369,323 of 3,214,874) sit at exactly 30. We can't tell a 31-day gap from a 90-day gap, and averages and standard deviations are biased downward. Flagged as `is_capped_gap`; Phase 2 will run sensitivity analysis with and without capped gaps |
| 4 | Keep NULL `days_since_prior_order` as NULL; it means "first order" | Exactly 206,209 NULLs, one per user, none on later orders. It's a structural NULL, not missing data, so first orders are excluded from gap statistics |
| 5 | Exclude `test` orders from basket-level analysis | All 75,000 `test` orders have no product rows (labels were hidden). They remain usable for order-level features |
| 6 | Unify `prior` and `train` baskets through a view with a `source_set` column | Keeps raw tables untouched while giving one place to query baskets; `UNION ALL` avoids a pointless dedupe because the sets cannot overlap |
| 7 | Treat `order_number = 100` as a truncation ceiling | 1,374 users (~0.67%) have exactly 100 orders, so order counts for them are lower bounds. Kept in the data; flagged for sensitivity checks in Phase 2 and 3 |
| 8 | Use the median gap as the primary "typical gap"; keep mean, SD, and an uncapped mean as secondary/sensitivity features | 20% of users have ≥50% capped gaps. Dropping capped gaps biases slow users toward looking fast; the median is robust to censoring below 50% |
| 9 | Build features from `prior` orders only; store each user's holdout order in a separate table | Prevents leakage. No user is observed fully churning, so the Phase 2 target will be a late return relative to the user's own rhythm |
| 10 | Segment users into `regular`, `mostly_capped`, `all_capped`, `constant_gap` rhythm classes | `all_capped` users (4.3%) have no measurable personal rhythm, and 36.6% still returned in under 30 days, so their gaps are censored, not stable. `constant_gap` users are mostly 2-gap coincidences |
| 11 | Require at least 5 prior gaps for personal z-scores; floor the SD at 1 day | 71% of users qualify; a personal SD from fewer gaps is mostly noise. Gaps are whole days, so SDs below 1 day are below the data's resolution. Sensitivity checks at 3 and 8 gaps in Step 2.5 |
| 12 | Label holdout orders as late / on time / unknown, not binary | About 31% of holdout gaps are capped at 30 (right-censored). A capped holdout below the z cut-off could still be late, so it stays "unknown" |
