/* ---------------------------------------------------------------------------
-- Case Study #5: Data Mart
-- Section A: Data Cleansing Steps
-- Author: Turki Alajmi
-- Date: March 2026
-- Tool used: Microsoft SQL Server (T-SQL)
--------------------------------------------------------------------------- */

------------------------------------------------------------------------
-- In a single query, perform the following operations and generate a
-- new table in the data_mart schema named clean_weekly_sales:
--
-- 1. Convert the week_date to a DATE format
-- 2. Add a week_number as the second column for each week_date value,
--    for example any value from the 1st of January to 7th of January
--    will be 1, 8th to 14th will be 2 etc
-- 3. Add a month_number with the calendar month for each week_date
--    value as the 3rd column
-- 4. Add a calendar_year column as the 4th column containing either
--    2018, 2019 or 2020 values
-- 5. Add age_band after segment using: 1=Young Adults, 2=Middle Aged,
--    3 or 4=Retirees. Null segment maps to 'unknown'
-- 6. Add demographic after age_band using: C=Couples, F=Families.
--    Null segment maps to 'unknown'
-- 7. Ensure all null string values in segment, age_band, and
--    demographic are replaced with 'unknown'
-- 8. Add avg_transaction as sales / transactions rounded to 2dp
------------------------------------------------------------------------

WITH main_date AS (
    SELECT
        CONVERT(DATE, week_date, 3) AS week_date,
        region,
        platform,
        CASE WHEN segment = 'null' THEN 'unknown' ELSE segment END AS segment,
        CASE WHEN segment = 'null' THEN 'unknown' ELSE LEFT(segment, 1) END AS segment_type,
        CASE WHEN segment = 'null' THEN 'unknown' ELSE RIGHT(segment, 1) END AS segment_age,
        customer_type,
        transactions,
        sales
    FROM data_mart.weekly_sales
)

SELECT
    week_date,
    ((DATEPART(DAYOFYEAR, week_date) - 1) / 7) + 1 AS week_number,
    DATEPART(MONTH, week_date) month_number,
    DATEPART(YEAR, week_date) AS calendar_year,
    region,
    platform,
    segment,
    CASE
        WHEN segment_age = '1' THEN 'Young Adults'
        WHEN segment_age = '2' THEN 'Middle Aged'
        WHEN segment_age IN ('3', '4') THEN 'Retirees'
        ELSE 'unknown'
        END AS age_band,
    CASE

        WHEN segment_type = 'C' THEN 'Couples'
        WHEN segment_type = 'F' THEN 'Families'
        ELSE 'unknown' END AS demographic,
    customer_type,
    transactions,
    sales,
    CAST((1.0 * sales) / transactions AS DECIMAL(10, 2)) AS avg_transaction
INTO data_mart.clean_weekly_sales
FROM main_date;