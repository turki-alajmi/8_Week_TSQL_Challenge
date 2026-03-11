/* ---------------------------------------------------------------------------
-- Case Study #3: Foodie-Fi
-- Section C: Challenge Payment Question
-- Author: Turki Alajmi
-- Date: March 2026
-- Tool used: Microsoft SQL Server (T-SQL)
--------------------------------------------------------------------------- */

-- 1. ANCHOR CTE: Retrieve initial active plans in 2020.
-- Using LEAD() to peek at the next plan's details to calculate exact cutoff dates.
-- Note: Trials (plan_id = 0) are excluded as they are not billed. Churns (plan_id = 4)
-- are temporarily kept to cap the billing cycle in the recursive step.
WITH main_data AS (
    SELECT
        s.customer_id,
        s.plan_id,
        p.plan_name,
        s.start_date,
        p.price,
        LEAD(p.plan_name) OVER (
            PARTITION BY customer_id
            ORDER BY s.start_date) AS next_plan_name,
        LEAD(start_date) OVER (
            PARTITION BY customer_id
            ORDER BY s.start_date) AS next_plan_date,
        LEAD(p.price) OVER (
            PARTITION BY customer_id
            ORDER BY s.start_date) AS next_plan_price
    FROM foodie_fi.subscriptions AS s
    INNER JOIN foodie_fi.plans AS p
        ON s.plan_id = p.plan_id
    WHERE s.plan_id <> 0
      AND s.start_date < '20210101'

    UNION ALL

-- 2. RECURSIVE CTE: Generate monthly payment dates.
    SELECT
        customer_id,
        plan_id,
        plan_name,
        CASE
            WHEN plan_id = 4 THEN start_date
            WHEN start_date < ISNULL(next_plan_date, '20210101') THEN DATEADD(MONTH, 1, start_date)
            END,
        price,
        next_plan_name,
        next_plan_date,
        next_plan_price
    FROM main_data

    -- Recursive termination conditions:
-- a) Stop generating payments once we hit 2021.
-- b) Stop generating payments once the next month's date overlaps with the start of a new plan.
-- c) Exclude Churns (4) and Annuals (3) from looping to prevent infinite billing.
    WHERE start_date < '20210101'
      AND DATEADD(MONTH, 1, start_date) <= ISNULL(next_plan_date, '20210101')
      AND plan_id NOT IN (4, 3)
),

-- 3. PRICING LOGIC: Use LAG() to identify the previous plan's price.
-- This is required to calculate the $9.90 deduction when a
-- customer upgrades from Basic Monthly to a Pro plan.
    basic_to_pro_price AS (
        SELECT
            customer_id,
            plan_id,
            plan_name,
            start_date,
            price,
            next_plan_name,
            next_plan_date,
            next_plan_price,
            LAG(plan_id) OVER (
                PARTITION BY customer_id
                ORDER BY start_date) last_plan,
            LAG(price) OVER (
                PARTITION BY customer_id
                ORDER BY start_date) last_price
        FROM main_data
-- Final Cleanup: Remove churn rows from the actual payment output.
-- The start_date <> next_plan_date Filters out duplicate rows that occur when
-- a customer upgrades from Pro Monthly to Annual — both plans share the same start date,
-- causing the monthly row to appear alongside the annual.
        WHERE plan_id <> 4
          AND (next_plan_date IS NULL OR start_date <> next_plan_date)
    )

-- 4. FINAL OUTPUT: Apply the upgrade deductions and sequence the payments.
SELECT
    customer_id,
    plan_id,
    plan_name,
    start_date,
    CASE
        WHEN plan_id IN (2, 3) AND last_plan = 1 THEN price - last_price
        ELSE price
        END AS amount_paid,
    RANK() OVER (
        PARTITION BY customer_id
        ORDER BY start_date) AS payment_order
INTO foodie_fi.payments
FROM basic_to_pro_price;

