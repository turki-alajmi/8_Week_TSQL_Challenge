------------------------------------------------------------------------
-- SECTION A: Customer Journey
-- Based off the 8 sample customers provided in the challenge, write a
-- brief description about each customer's onboarding journey.
------------------------------------------------------------------------
SELECT
    customer_id,
    plan_name,
    start_date,
    price
FROM foodie_fi.subscriptions AS s
INNER JOIN foodie_fi.plans AS p
    ON s.plan_id = p.plan_id
WHERE customer_id IN (1, 2, 11, 13, 15, 16, 18, 19)
ORDER BY
    customer_id,
    start_date
/*
Customer 1: Trial (2020-08-01) → manually downgraded to Basic Monthly (2020-08-08).

Customer 2: Trial (2020-09-20) → manually upgraded to Pro Annual (2020-09-27).

Customer 11: Trial (2020-11-19) → Churned (2020-11-26).

Customer 13: Trial (2020-12-15) → manually downgraded to Basic Monthly (2020-12-22) → upgraded to Pro Monthly (2021-03-29).

Customer 15: Trial (2020-03-17) → auto-renewed to Pro Monthly (2020-03-24) → Churned (2020-04-29).

Customer 16: Trial (2020-05-31) → manually downgraded to Basic Monthly (2020-06-07) → upgraded to Pro Annual (2020-10-21).

Customer 18: Trial (2020-07-06) → auto-renewed to Pro Monthly (2020-07-13).

Customer 19: Trial (2020-06-22) → auto-renewed to Pro Monthly (2020-06-29) → upgraded to Pro Annual (2020-08-29).

 */


