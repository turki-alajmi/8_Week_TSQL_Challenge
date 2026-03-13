/* ---------------------------------------------------------------------------
-- Case Study #5: Data Mart
-- Section B: Data Exploration
-- Author: Turki Alajmi
-- Date: March 2026
-- Tool used: Microsoft SQL Server (T-SQL)
--------------------------------------------------------------------------- */

------------------------------------------------------------------------
-- Q1: What day of the week is used for each week_date value?
------------------------------------------------------------------------

SELECT
    DATENAME(WEEKDAY, week_date) day_of_week,
    COUNT(*) as amount_used
FROM data_mart.clean_weekly_sales
GROUP BY
    DATENAME(WEEKDAY, week_date);

------------------------------------------------------------------------
-- Q2: What range of week numbers are missing from the dataset?
------------------------------------------------------------------------

WITH cte AS (
    SELECT
        1 AS missing_week_number
    UNION ALL
    SELECT
        missing_week_number + 1
    FROM cte
    WHERE missing_week_number < 52
)
SELECT
    missing_week_number
FROM cte

EXCEPT

SELECT DISTINCT
    week_number
FROM data_mart.clean_weekly_sales;

------------------------------------------------------------------------
-- Q3: How many total transactions were there for each year in the dataset?
------------------------------------------------------------------------

SELECT
    calendar_year,
    SUM(transactions) AS total_transaction
FROM data_mart.clean_weekly_sales
GROUP BY
    calendar_year;

------------------------------------------------------------------------
-- Q4: What is the total sales for each region for each month?
------------------------------------------------------------------------

SELECT
    region,
    month_number,
    SUM(CAST(sales AS BIGINT)) total_monthly_sales
FROM data_mart.clean_weekly_sales
GROUP BY
    region,

    month_number
ORDER BY
    region,
    month_number;

------------------------------------------------------------------------
-- Q5: What is the total count of transactions for each platform?
------------------------------------------------------------------------

SELECT
    platform,
    COUNT(*) as count_of_transaction
FROM data_mart.clean_weekly_sales
GROUP BY platform;

------------------------------------------------------------------------
-- Q6: What is the percentage of sales for Retail vs Shopify for each month?
------------------------------------------------------------------------

WITH main_data AS (
    SELECT
        platform,
        month_number,
        CAST(sales AS BIGINT) AS platfrom_sales,
        SUM(CAST(sales AS BIGINT)) OVER (
            PARTITION BY month_number) AS total_sales
    FROM data_mart.clean_weekly_sales
)

SELECT
    platform,
    month_number,
    CAST((SUM(platfrom_sales) * 100.0) / max(total_sales) AS DECIMAL(5, 2)) AS platform_sales_percentage
FROM main_data
GROUP BY
    platform,
    month_number;

------------------------------------------------------------------------
-- Q7: What is the percentage of sales by demographic for each year
-- in the dataset?
------------------------------------------------------------------------

WITH cte AS (
    SELECT
        demographic,
        calendar_year,
        CAST(sales AS BIGINT) AS sales,
        SUM(CAST(sales AS BIGINT)) OVER (
            PARTITION BY calendar_year) AS yearly_sales
    FROM data_mart.clean_weekly_sales
)

SELECT
    calendar_year,
    demographic,
    CAST((SUM(sales) * 100.0) / MAX(yearly_sales) AS DECIMAL(5, 2)) as percentage_of_sales
FROM cte
GROUP BY
    calendar_year,
    demographic
ORDER BY
    calendar_year,
    demographic;

------------------------------------------------------------------------
-- Q8: Which age_band and demographic values contribute the most to
-- Retail sales?
------------------------------------------------------------------------

SELECT
    age_band,
    demographic,
    SUM(CAST(sales AS BIGINT)) AS total_sales
FROM data_mart.clean_weekly_sales
WHERE platform = 'Retail'
GROUP BY
    age_band,
    demographic
ORDER BY
    total_sales DESC;

------------------------------------------------------------------------
-- Q9: Can we use the avg_transaction column to find the average transaction
-- size for each year for Retail vs Shopify? If not - how would you
-- calculate it instead?
------------------------------------------------------------------------

/*
Summing or averaging the avg_transaction column produces a meaningless number
you cannot average averages when each row represents a different transaction volume.
Instead, recalculate from scratch: SUM(sales) / SUM(transactions).
 */

SELECT
    calendar_year,
    platform,
    CAST((SUM(CAST(sales AS BIGINT)) * 1.0) / SUM(CAST(transactions AS BIGINT)) AS DECIMAL(7, 2)) AS true_avg
FROM data_mart.clean_weekly_sales
GROUP BY
    calendar_year,
    platform;