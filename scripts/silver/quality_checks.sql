/*
===============================================================================
Cleaning the data - Data Quality Checks
===============================================================================
Script Purpose:
    This stored procedure performs the Data Quality checks
===============================================================================
*/



-- Check For Nulls or Duplicates in Primary Key
-- Expectations: No Result
USE DataWarehouse;
GO

SELECT
    cst_id,
    COUNT(*) AS cnt
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING cst_id IS NULL OR COUNT(*) > 1;

SELECT
    prd_id,
    COUNT(*) AS cnt
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING prd_id IS NULL OR COUNT(*) > 1;

-- Sting Values
-- Check for unwanted spaces in string values.
-- Expectations: No Result
SELECT
    *
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT
    cst_lastname
FROM bronze.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

SELECT
    prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);


-- Data Standardization & Consistency
-- Check for consistency of values in low cardinality columns.
-- Expectations: No Result

SELECT DISTINCT cst_marital_status
FROM bronze.crm_cust_info;

SELECT DISTINCT cst_gndr
FROM bronze.crm_cust_info;

SELECT DISTINCT prd_line
FROM bronze.crm_prd_info;


-- Check for NULLs and Negative Numbers
-- Expectation: No Result
SELECT prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL


-- Check Invalid Date Orders
SELECT *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt

-- Solution
SELECT 
    prd_id,
    prd_key,
    prd_nm,
    prd_start_dt,
    prd_end_dt,
    -- Access values from the next row within a window
    DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt ASC)) AS prd_end_dt_test
    -- LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt ASC) AS prd_end_dt_test
FROM bronze.crm_prd_info
WHERE prd_key IN ('AC-HE-HL-U509-R', 'AC-HE-HL-U509')

SELECT *
FROM silver.crm_prd_info


/* Check for Unwanted Spaces */
SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
FROM bronze.crm_sales_details
WHERE sls_ord_num != TRIM(sls_ord_num)


SELECT
    NULLIF(CAST(sls_order_dt AS INT), 0) sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0
OR LEN(sls_order_dt) != 8
OR sls_order_dt > 20500101
OR sls_order_dt < 19000101

-- Invalid Date
SELECT
    *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt;

-- Check Data Consistency: Between Sales, Quantity and Price
-- >> Sales = Quantity * Price
-- >> Values must not be NULL, zero, or negative

SELECT 
    sls_sales,
    sls_quantity,
    sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price

-- CASE WHEN 
-- DATA NORMALISATION