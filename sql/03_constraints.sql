-- sql/03_constraints.sql 

-- 0. Reset: drop FKs first (they depend on PKs), then PKs, then indexes
ALTER TABLE raw.order_products_train DROP CONSTRAINT IF EXISTS fk_opt_product;
ALTER TABLE raw.order_products_train DROP CONSTRAINT IF EXISTS fk_opt_order;
ALTER TABLE raw.order_products_prior DROP CONSTRAINT IF EXISTS fk_opp_product;
ALTER TABLE raw.order_products_prior DROP CONSTRAINT IF EXISTS fk_opp_order;
ALTER TABLE raw.products             DROP CONSTRAINT IF EXISTS fk_products_department;
ALTER TABLE raw.products             DROP CONSTRAINT IF EXISTS fk_products_aisle;

ALTER TABLE raw.order_products_train DROP CONSTRAINT IF EXISTS pk_order_products_train;
ALTER TABLE raw.order_products_prior DROP CONSTRAINT IF EXISTS pk_order_products_prior;
ALTER TABLE raw.orders               DROP CONSTRAINT IF EXISTS pk_orders;
ALTER TABLE raw.products             DROP CONSTRAINT IF EXISTS pk_products;
ALTER TABLE raw.departments          DROP CONSTRAINT IF EXISTS pk_departments;
ALTER TABLE raw.aisles               DROP CONSTRAINT IF EXISTS pk_aisles;

DROP INDEX IF EXISTS raw.idx_orders_user_ordernum;
DROP INDEX IF EXISTS raw.idx_opp_product;
DROP INDEX IF EXISTS raw.idx_opt_product;

-- 1. Primary keys
ALTER TABLE raw.aisles      ADD CONSTRAINT pk_aisles      PRIMARY KEY (aisle_id);
ALTER TABLE raw.departments ADD CONSTRAINT pk_departments PRIMARY KEY (department_id);
ALTER TABLE raw.products    ADD CONSTRAINT pk_products    PRIMARY KEY (product_id);
ALTER TABLE raw.orders      ADD CONSTRAINT pk_orders      PRIMARY KEY (order_id);
ALTER TABLE raw.order_products_prior
    ADD CONSTRAINT pk_order_products_prior PRIMARY KEY (order_id, product_id);
ALTER TABLE raw.order_products_train
    ADD CONSTRAINT pk_order_products_train PRIMARY KEY (order_id, product_id);

-- 2. Foreign keys
ALTER TABLE raw.products
    ADD CONSTRAINT fk_products_aisle
    FOREIGN KEY (aisle_id) REFERENCES raw.aisles (aisle_id);
ALTER TABLE raw.products
    ADD CONSTRAINT fk_products_department
    FOREIGN KEY (department_id) REFERENCES raw.departments (department_id);
ALTER TABLE raw.order_products_prior
    ADD CONSTRAINT fk_opp_order
    FOREIGN KEY (order_id) REFERENCES raw.orders (order_id);
ALTER TABLE raw.order_products_prior
    ADD CONSTRAINT fk_opp_product
    FOREIGN KEY (product_id) REFERENCES raw.products (product_id);
ALTER TABLE raw.order_products_train
    ADD CONSTRAINT fk_opt_order
    FOREIGN KEY (order_id) REFERENCES raw.orders (order_id);
ALTER TABLE raw.order_products_train
    ADD CONSTRAINT fk_opt_product
    FOREIGN KEY (product_id) REFERENCES raw.products (product_id);

-- 3. Indexes
CREATE INDEX idx_orders_user_ordernum ON raw.orders (user_id, order_number);
CREATE INDEX idx_opp_product ON raw.order_products_prior (product_id);
CREATE INDEX idx_opt_product ON raw.order_products_train (product_id);

-- 4. Refresh planner statistics
ANALYZE raw.aisles;
ANALYZE raw.departments;
ANALYZE raw.products;
ANALYZE raw.orders;
ANALYZE raw.order_products_prior;
ANALYZE raw.order_products_train;