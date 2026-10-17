-- =========================================================
-- Olist E-Commerce: create schema + tables + bulk import
-- Before running: replace /path/to/ with your actual folder
-- (on Windows use forward slashes, e.g. C:/Users/you/olist/)
-- =========================================================

-- 0. Allow loading local files (needs to be run once; may need admin rights)
SET GLOBAL local_infile = 1;

CREATE DATABASE IF NOT EXISTS olist
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
USE olist;

-- =========================================================
-- 1. Create tables
-- =========================================================

DROP TABLE IF EXISTS olist_customers_dataset;
CREATE TABLE olist_customers_dataset (
  customer_id              VARCHAR(32) PRIMARY KEY,
  customer_unique_id       VARCHAR(32) NOT NULL,
  customer_zip_code_prefix VARCHAR(10),
  customer_city            VARCHAR(100),
  customer_state           CHAR(2)
);

DROP TABLE IF EXISTS olist_orders_dataset;
CREATE TABLE olist_orders_dataset (
  order_id                      VARCHAR(32) PRIMARY KEY,
  customer_id                   VARCHAR(32) NOT NULL,
  order_status                  VARCHAR(20),
  order_purchase_timestamp      DATETIME,
  order_approved_at             DATETIME NULL,
  order_delivered_carrier_date  DATETIME NULL,
  order_delivered_customer_date DATETIME NULL,
  order_estimated_delivery_date DATETIME
);

DROP TABLE IF EXISTS olist_order_items_dataset;
CREATE TABLE olist_order_items_dataset (
  order_id            VARCHAR(32) NOT NULL,
  order_item_id       INT NOT NULL,
  product_id          VARCHAR(32) NOT NULL,
  seller_id           VARCHAR(32) NOT NULL,
  shipping_limit_date DATETIME,
  price               DECIMAL(10,2),
  freight_value       DECIMAL(10,2),
  PRIMARY KEY (order_id, order_item_id)
);

DROP TABLE IF EXISTS olist_order_payments_dataset;
CREATE TABLE olist_order_payments_dataset (
  order_id             VARCHAR(32) NOT NULL,
  payment_sequential   INT NOT NULL,
  payment_type         VARCHAR(20),
  payment_installments INT,
  payment_value        DECIMAL(10,2),
  PRIMARY KEY (order_id, payment_sequential)
);

-- review_id is NOT unique in this dataset, so no primary key here
DROP TABLE IF EXISTS olist_order_reviews_dataset;
CREATE TABLE olist_order_reviews_dataset (
  review_id               VARCHAR(32) NOT NULL,
  order_id                VARCHAR(32) NOT NULL,
  review_score            TINYINT,
  review_comment_title    VARCHAR(255),
  review_comment_message  TEXT,
  review_creation_date    DATETIME,
  review_answer_timestamp DATETIME,
  INDEX idx_reviews_order (order_id)
);

DROP TABLE IF EXISTS olist_products_dataset;
CREATE TABLE olist_products_dataset (
  product_id                 VARCHAR(32) PRIMARY KEY,
  product_category_name      VARCHAR(100) NULL,
  product_name_lenght        INT NULL,   -- typo is in the original data
  product_description_lenght INT NULL,   -- typo is in the original data
  product_photos_qty         INT NULL,
  product_weight_g           INT NULL,
  product_length_cm          INT NULL,
  product_height_cm          INT NULL,
  product_width_cm           INT NULL
);

DROP TABLE IF EXISTS olist_sellers_dataset;
CREATE TABLE olist_sellers_dataset (
  seller_id              VARCHAR(32) PRIMARY KEY,
  seller_zip_code_prefix VARCHAR(10),
  seller_city            VARCHAR(100),
  seller_state           CHAR(2)
);

-- zip prefix is NOT unique here (many lat/lng per prefix)
DROP TABLE IF EXISTS olist_geolocation_dataset;
CREATE TABLE olist_geolocation_dataset (
  geolocation_zip_code_prefix VARCHAR(10),
  geolocation_lat             DECIMAL(18,14),
  geolocation_lng             DECIMAL(18,14),
  geolocation_city            VARCHAR(100),
  geolocation_state           CHAR(2),
  INDEX idx_geo_zip (geolocation_zip_code_prefix)
);

DROP TABLE IF EXISTS product_category_name_translation;
CREATE TABLE product_category_name_translation (
  product_category_name         VARCHAR(100) PRIMARY KEY,
  product_category_name_english VARCHAR(100)
);

-- =========================================================
-- 2. Load data
-- If a load reports 0 rows or garbled last column, change
-- LINES TERMINATED BY '\n'  to  '\r\n'
-- =========================================================

LOAD DATA LOCAL INFILE '/Users/liuzhihe/Desktop/E-commerce SQL/olist_customers_dataset.csv'
INTO TABLE olist_customers_dataset
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Empty delivery dates -> NULL
LOAD DATA LOCAL INFILE '/Users/liuzhihe/Desktop/E-commerce SQL/olist_orders_dataset.csv'
INTO TABLE olist_orders_dataset
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, customer_id, order_status, order_purchase_timestamp,
 @approved, @carrier, @delivered, order_estimated_delivery_date)
SET order_approved_at             = NULLIF(@approved, ''),
    order_delivered_carrier_date  = NULLIF(@carrier, ''),
    order_delivered_customer_date = NULLIF(@delivered, '');

LOAD DATA LOCAL INFILE '/Users/liuzhihe/Desktop/E-commerce SQL/olist_order_items_dataset.csv'
INTO TABLE olist_order_items_dataset
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '/Users/liuzhihe/Desktop/E-commerce SQL/olist_order_payments_dataset.csv'
INTO TABLE olist_order_payments_dataset
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Review comments contain commas and line breaks inside quotes
LOAD DATA LOCAL INFILE '/Users/liuzhihe/Desktop/E-commerce SQL/olist_order_reviews_dataset.csv'
INTO TABLE olist_order_reviews_dataset
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(review_id, order_id, review_score, @title, @msg,
 review_creation_date, review_answer_timestamp)
SET review_comment_title   = NULLIF(@title, ''),
    review_comment_message = NULLIF(@msg, '');

-- Some products have empty category / numeric fields
LOAD DATA LOCAL INFILE '/Users/liuzhihe/Desktop/E-commerce SQL/olist_products_dataset.csv'
INTO TABLE olist_products_dataset
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, @cat, @name_len, @desc_len, @photos,
 @weight, @length, @height, @width)
SET product_category_name      = NULLIF(@cat, ''),
    product_name_lenght        = NULLIF(@name_len, ''),
    product_description_lenght = NULLIF(@desc_len, ''),
    product_photos_qty         = NULLIF(@photos, ''),
    product_weight_g           = NULLIF(@weight, ''),
    product_length_cm          = NULLIF(@length, ''),
    product_height_cm          = NULLIF(@height, ''),
    product_width_cm           = NULLIF(@width, '');

LOAD DATA LOCAL INFILE '/Users/liuzhihe/Desktop/E-commerce SQL/olist_sellers_dataset.csv'
INTO TABLE olist_sellers_dataset
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '/Users/liuzhihe/Desktop/E-commerce SQL/olist_geolocation_dataset.csv'
INTO TABLE olist_geolocation_dataset
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '/Users/liuzhihe/Desktop/E-commerce SQL/product_category_name_translation.csv'
INTO TABLE product_category_name_translation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- =========================================================
-- 3. Check row counts
-- Expected (public Kaggle version), approx:
--   customers 99,441 | orders 99,441 | order_items 112,650
--   payments 103,886 | reviews 99,224 | products 32,951
--   sellers 3,095 | geolocation 1,000,163 | translation 71
-- =========================================================
SELECT 'customers'   AS tbl, COUNT(*) AS n FROM olist_customers_dataset
UNION ALL SELECT 'orders',      COUNT(*) FROM olist_orders_dataset
UNION ALL SELECT 'order_items', COUNT(*) FROM olist_order_items_dataset
UNION ALL SELECT 'payments',    COUNT(*) FROM olist_order_payments_dataset
UNION ALL SELECT 'reviews',     COUNT(*) FROM olist_order_reviews_dataset
UNION ALL SELECT 'products',    COUNT(*) FROM olist_products_dataset
UNION ALL SELECT 'sellers',     COUNT(*) FROM olist_sellers_dataset
UNION ALL SELECT 'geolocation', COUNT(*) FROM olist_geolocation_dataset
UNION ALL SELECT 'translation', COUNT(*) FROM product_category_name_translation;