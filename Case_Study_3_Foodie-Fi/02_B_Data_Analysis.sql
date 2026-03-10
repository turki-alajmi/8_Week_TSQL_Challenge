/* ---------------------------------------------------------------------------
-- Case Study #3: Foodie-Fi
-- Section B: Data Analysis Questions
-- Author: Turki Alajmi
-- Date: March 2026
-- Tool used: Microsoft SQL Server (T-SQL)
--------------------------------------------------------------------------- */

------------------------------------------------------------------------
-- Q01: How many customers has Foodie-Fi ever had?
------------------------------------------------------------------------

SELECT
    COUNT(DISTINCT customer_id) AS unique_customers
FROM foodie_fi.subscriptions;

------------------------------------------------------------------------
-- Q02: What is the monthly distribution of trial plan start_date values
-- for our dataset - use the start of the month as the group by value
------------------------------------------------------------------------

SELECT
    DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1) AS histogram,
    COUNT(*)
FROM foodie_fi.subscriptions
WHERE plan_id = 0
GROUP BY
    DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1)
ORDER BY
    histogram;

------------------------------------------------------------------------
-- Q03: What plan start_date values occur after the year 2020 for our dataset?
-- Show the breakdown by count of events for each plan_name
------------------------------------------------------------------------

SELECT
    plan_name,
    COUNT(*) AS events_after_2020
FROM foodie_fi.subscriptions AS s
INNER JOIN foodie_fi.plans AS p
    ON s.plan_id = p.plan_id
WHERE start_date >= '20210101'
GROUP BY
    plan_name;

------------------------------------------------------------------------
-- Q04: What is the customer count and percentage of customers who
-- have churned rounded to 1 decimal place?
------------------------------------------------------------------------

SELECT
    SUM(CASE WHEN plan_id = 4 THEN 1 ELSE 0 END) AS churned_count,
    cast(100.0 * (SUM(CASE WHEN plan_id = 4 THEN 1 ELSE 0 END))
        /
     COUNT(DISTINCT customer_id) as DECIMAL(5,1)) as churned_percentage
FROM foodie_fi.subscriptions;

------------------------------------------------------------------------
-- Q05: How many customers have churned straight after their initial free
-- trial - what percentage is this rounded to the nearest whole number?
------------------------------------------------------------------------

WITH cte AS (
    SELECT
        customer_id,
        plan_id,
        start_date,
        LAG(plan_id) OVER (
            PARTITION BY customer_id
            ORDER BY start_date) AS lag_id
    FROM foodie_fi.subscriptions
),
    churn_count AS (
        SELECT
            SUM(CASE
                    WHEN plan_id = 4 AND lag_id = 0
                        THEN 1
                    ELSE 0 END) AS immediate_churn

        FROM cte
    )
SELECT
    immediate_churn,
    CAST((100.0 * (immediate_churn) / uni_cus) AS DECIMAL(5, 0)) AS immediate_churn_percentage

FROM churn_count
CROSS JOIN (
    SELECT
        COUNT(DISTINCT customer_id) AS uni_cus
    FROM foodie_fi.subscriptions
) AS cust_unique;

------------------------------------------------------------------------
-- Q06: What is the number and percentage of customer plans after their
-- initial free trial?
------------------------------------------------------------------------

WITH rank_cte AS (
    SELECT
        s.customer_id,
        s.plan_id,
        p.plan_name,
        s.start_date,
        ROW_NUMBER() OVER (
            PARTITION BY s.customer_id
            ORDER BY start_date, s.plan_id
            ) AS after_trial_sub

    FROM foodie_fi.subscriptions AS s
    INNER JOIN foodie_fi.plans p ON s.plan_id = p.plan_id
    WHERE p.plan_id <> 0
),
    filter_cte AS (
        SELECT
            customer_id,
            plan_id,
            plan_name,
            start_date,
            after_trial_sub,
            count(*) OVER ( ) AS all_plans_counts
        FROM rank_cte
        WHERE after_trial_sub = 1
    )

SELECT
    plan_name,
    COUNT(plan_name) AS plans_after_trial,
    CAST((100.00 * COUNT(plan_name) / MAX(all_plans_counts)) AS DECIMAL(5, 1)) AS percent_plans_after_trial

FROM filter_cte
GROUP BY
    plan_name;

------------------------------------------------------------------------
-- Q07: What is the customer count and percentage breakdown of all 5
-- plan_name values at 2020-12-31?
------------------------------------------------------------------------

-- Filter the date and assign a rank 1 to the last plan
WITH current_plan_rank AS (
    SELECT
        customer_id,
        plan_id,
        start_date,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY start_date DESC, plan_id
            ) AS cust_plan_ranking
    FROM foodie_fi.subscriptions
    WHERE start_date < '20210101'
),
-- Filter to the current plan, aggregates a count column to divide later
    filtering AS (
        SELECT
            customer_id,
            plan_name,
            COUNT(*) OVER ( ) AS all_plans_counts

        FROM current_plan_rank AS cur
        INNER JOIN foodie_fi.plans AS p
            ON p.plan_id = cur.plan_id
        WHERE cust_plan_ranking = 1

    )
SELECT
    plan_name,
    COUNT(plan_name) AS current_plan_count,
    CAST((100.0 * COUNT(plan_name)) / MAX(all_plans_counts) AS DECIMAL(5, 1)) AS current_plan_percent
FROM filtering
GROUP BY
    plan_name;

------------------------------------------------------------------------
-- Q08: How many customers have upgraded to an annual plan in 2020?
------------------------------------------------------------------------

SELECT
    COUNT(*) AS annual_upgrade_2020
FROM foodie_fi.subscriptions
WHERE (start_date >= '20200101' AND start_date < '20210101')
  AND plan_id = 3;

------------------------------------------------------------------------
-- Q09: How many days on average does it take for a customer to upgrade to an annual
--      plan from the day they join Foodie-Fi?
------------------------------------------------------------------------

WITH trial AS (
    SELECT
        customer_id,
        start_date AS trial_date
    FROM foodie_fi.subscriptions
    WHERE plan_id = 0
),
    annual AS (
        SELECT
            customer_id,
            start_date AS annual_date
        FROM foodie_fi.subscriptions
        WHERE plan_id = 3
    )
SELECT
    AVG(CAST(DATEDIFF(DAY, trial_date, annual_date) AS DECIMAL(5,2))) AS avg_days_to_annual
FROM trial
INNER JOIN annual
    ON trial.customer_id = annual.customer_id;


------------------------------------------------------------------------
-- Q10: Can you further breakdown this average value into 30 day periods
-- (i.e. 0-30 days, 31-60 days etc)
------------------------------------------------------------------------

WITH trial AS (
    SELECT
        customer_id,
        start_date AS trial_date
    FROM foodie_fi.subscriptions
    WHERE plan_id = 0
),
    annual AS (
        SELECT
            customer_id,
            start_date AS annual_date
        FROM foodie_fi.subscriptions
        WHERE plan_id = 3
    ),
    histogram AS (

        SELECT
            annual.customer_id,
            ((DATEDIFF(DAY, trial_date, annual_date) / 30) + 1) * 30 AS histo
        FROM trial
        INNER JOIN annual
            ON trial.customer_id = annual.customer_id
    )
SELECT
    CONCAT(histo - 29, '-', histo) AS period_range,

    COUNT(customer_id) AS annual_gain
FROM histogram
GROUP BY
    histo;

------------------------------------------------------------------------
-- Q11: How many customers downgraded from a pro monthly to a basic
-- monthly plan in 2020?
------------------------------------------------------------------------

WITH pro AS (
    SELECT
        customer_id,
        plan_id,
        start_date
    FROM foodie_fi.subscriptions
    WHERE start_date < '20210101'
      AND plan_id = 2
),

    basic AS (
        SELECT
            customer_id,
            plan_id,
            start_date
        FROM foodie_fi.subscriptions
        WHERE start_date < '20210101'
          AND plan_id = 1

    )

SELECT
    basic.customer_id,
    basic.start_date AS basic_start,
    pro.start_date AS pro_start
FROM basic
INNER JOIN pro
    ON pro.customer_id = basic.customer_id
    AND basic.start_date > pro.start_date;
/*
 THIS RETURNS 0 ROWS, AKA NO ONE DOWNGRADED FROM PRO MONTHLY TO BASIC MONTHLY IN 2020
 */