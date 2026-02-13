/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================
USE DataWarehouse;
GO

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS 
-- Get the entire view of the customers:
SELECT
    -- Surrogate Keys: System generated unique identifier assigned to each record 
    ROW_NUMBER() OVER(ORDER BY cst_id) AS customer_key,
    ci.cst_id customer_id,
    ci.cst_key customer_number,
    ci.cst_firstname first_name,
    ci.cst_lastname last_name,
    la.cntry country,
    ci.cst_marital_status marital_status,
    CASE
        WHEN  ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM is the Master for gender information
        ELSE COALESCE(ca.gen, 'n/a')
    END gender,
    ca.bdate birth_date,
    ci.cst_create_date create_date 
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON        ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON        ci.cst_key = la.cid;
GO

-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS 
-- Get the entire view of the products:
SELECT
    ROW_NUMBER() OVER(ORDER BY pi.prd_start_dt, pi.prd_key) AS product_key,
    pi.prd_id product_id,
    pi.prd_key product_number,
    pi.prd_nm product_name,
    cat_id category_id,
    pcg.cat category,
    pcg.subcat ubcategory,
    pcg.maintenance,
    pi.prd_cost cost,
    pi.prd_line product_line,
    pi.prd_start_dt [start_date]
FROM silver.crm_prd_info pi
LEFT JOIN silver.erp_px_cat_g1v2 pcg
ON pi.cat_id = pcg.id
WHERE prd_end_dt IS NULL -- Filter out all historical data
GO

-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- Use the dimension surrogate instead of IDs to easily connect facts with dimensions
-- DATA LOOKUP 
-- =============================================================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fac_sales AS 
-- Get the entire view of the products:
SELECT
    sd.sls_ord_num order_number,
    pr.product_key,
    c.customer_key,
    sd.sls_order_dt order_date,
    sd.sls_ship_dt shipping_date,
    sd.sls_due_dt due_date,
    sd.sls_sales sales_amount,
    sd.sls_quantity quantity,
    sd.sls_price price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers c
ON sd.sls_cust_id = c.customer_id
GO