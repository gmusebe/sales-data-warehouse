/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs quality checks to validate the integrity, consistency, 
    and accuracy of the Gold Layer. These checks ensure:
    - Uniqueness of surrogate keys in dimension tables.
    - Referential integrity between fact and dimension tables.
    - Validation of relationships in the data model for analytical purposes.

Usage Notes:
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

USE DataWarehouse;
GO
-- ====================================================================
-- Checking 'gold.dim_customers'
-- ====================================================================
-- Check for Uniqueness of Customer Key in gold.dim_customers
-- Expectation: No results 

SELECT
    cst_id,
    COUNT(*) count
FROM(
-- Get the entire view of the customers:
SELECT
    ci.cst_id,
    ci.cst_key,
    ci.cst_firstname,
    ci.cst_lastname,
    ci.cst_marital_status,
    ci.cst_gndr,
    ci.cst_create_date,
    ca.bdate,
    ca.gen,
    la.cntry
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON        ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON        ci.cst_key = la.cid
) t 
GROUP BY cst_id
HAVING COUNT(*) != 1;

-- OR

SELECT 
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;


SELECT DISTINCT
    -- ci.cst_id,
    ci.cst_gndr,
    ca.gen,
    CASE
        WHEN  ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM is the Master for gender information
        ELSE COALESCE(ca.gen, 'n/a')
    END new_gen
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON        ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON        ci.cst_key = la.cid
-- WHERE ci.cst_gndr != ca.gen
ORDER BY 1,2

-- ====================================================================
-- Checking 'gold.product_key'
-- ====================================================================
-- Check for Uniqueness of Product Key in gold.dim_products
-- Expectation: No results 
SELECT 
 product_key,
 COUNT(*) count
FROM(
SELECT 
    pi.prd_id product_id,
    cat_id category_id,
    pi.prd_key product_key,
    pi.prd_nm product_name,
    pcg.cat product_category,
    pcg.subcat product_subcategory,
    pi.prd_cost product_cost,
    pi.prd_line product_line,
    pcg.maintenance,
    pi.prd_start_dt [start_date]
FROM silver.crm_prd_info pi
LEFT JOIN silver.erp_px_cat_g1v2 pcg
ON pi.cat_id = pcg.id
WHERE prd_end_dt IS NULL -- Filter out all historical data
) t
GROUP BY product_key
HAVING COUNT(*) != 1;

-- OR

SELECT 
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- ====================================================================
-- Checking 'gold.fact_sales'
-- ====================================================================
-- Check the data model connectivity between fact and dimensions

-- FOREIGN KEY Integrity
SELECT *
FROM gold.fac_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
WHERE p.product_key  IS NULL