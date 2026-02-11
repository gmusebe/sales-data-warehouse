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


INSERT INTO silver.crm_sales_details(
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
)
SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    CASE
        WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
        ELSE CAST(sls_order_dt AS DATE)
    END sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    -- If Sales is negative, zero or null, derive it using Quantity and Price
    -- If Price is zero or null, calculate using Quantity and Sales
    -- If Price is negative, convert to a positive
    CASE
        WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales
    END AS sls_sales,
    sls_quantity,
    CASE
        WHEN sls_price IS NULL OR sls_price <= 0
            THEN sls_sales / NULLIF(sls_quantity, 0)
		ELSE sls_price  -- Derive price if original value is invalid
	END AS sls_price
FROM bronze.crm_sales_details

SELECT  DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price


INSERT INTO silver.erp_cust_az12(cid, bdate, gen)
SELECT
    CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
    ELSE cid
    END cid,
    CASE WHEN bdate > GETDATE() THEN NULL
    ELSE bdate
    END bdate,
    CASE
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
        ELse 'n/a'
    END gen
FROM bronze.erp_cust_az12
