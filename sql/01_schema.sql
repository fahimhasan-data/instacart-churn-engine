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

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('raw', 'analytics', 'features')
ORDER BY 1, 2;