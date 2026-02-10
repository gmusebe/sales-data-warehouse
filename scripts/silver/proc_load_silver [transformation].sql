-- Check For Nulls or Duplicates in Primary Key
-- Expectations: No Result
USE DataWarehouse;
GO

-- Loading silver.crm_cust_info
INSERT INTO silver.crm_cust_info (
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date)
SELECT
    cst_id,
    cst_key,

    -- TRANSFORMATIONS: Remove unwanted spaces: Data Consistency & Uniformity
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    -- TRANSFORMATIONS: Data Normalization & Standardization
    CASE
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
        ELSE 'n/a' -- TRANSFORMATIONS: Handle Missing Values: Fill blanks with default value
    END AS cst_marital_status,
    CASE  
        WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
        WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        ELSE 'n/a'
    END AS cst_gndr,
    cst_create_date
-- TRANSFORMATIONS: Remove Duplicates: Keep the most relevant record based
FROM (
SELECT
-- Assign a unique number to each row in a result set, based on a defined order.
*,
ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
FROM bronze.crm_cust_info
WHERE cst_id IS NOT NULL
) t
WHERE flag_last = 1; -- Select the most recent record per customer


-- Loading silver.crm_prd_info
INSERT INTO silver.crm_prd_info (
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt)
SELECT
    prd_id, -- No missing value and duplicates
    -- Deriving two new columns:
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
    SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
    prd_nm,
    ISNULL(prd_cost, 0) AS prd_cost, -- Handling Missing Information
    CASE  UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a'
    END AS prd_line,
    CAST(prd_start_dt AS DATE) prd_start_dt, -- Datatype Casting
    CAST(
        DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt ASC)) 
        AS DATE
    ) AS prd_end_dt -- Calculate end date as one day before the next start date
FROM bronze.crm_prd_info;


