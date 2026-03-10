/* ---------------------------------------------------------------------------
-- Case Study #2: Pizza Runner
-- Section A: Pizza Metrics
-- Author: Turki Alajmi
-- Date: March 2026
-- Tool used: Microsoft SQL Server (T-SQL)
--------------------------------------------------------------------------- */
------------------------------------------------------------------------
--Q01 How many pizzas were ordered?
------------------------------------------------------------------------
SELECT
    COUNT(order_id) AS order_count
FROM customer_orders_clean;

------------------------------------------------------------------------
--Q02 How many unique customer orders were made?
------------------------------------------------------------------------
SELECT
    COUNT(DISTINCT order_id) AS distinct_order_count
FROM customer_orders_clean;

------------------------------------------------------------------------
--Q03 How many successful orders were delivered by each runner?
------------------------------------------------------------------------
SELECT
    runner_id,
    COUNT(pickup_time) AS delivery_counts
FROM runner_orders_clean
WHERE cancellation IS NULL
GROUP BY
    runner_id;

------------------------------------------------------------------------
--Q04 How many of each type of pizza was delivered?
------------------------------------------------------------------------
SELECT
    c.pizza_id,
    COUNT(*) AS counts
FROM customer_orders_clean AS c
INNER JOIN runner_orders_clean AS r
    ON r.order_id = c.order_id
WHERE r.cancellation IS NULL
GROUP BY
    c.pizza_id;

------------------------------------------------------------------------
--Q05 How many Vegetarian and Meatlovers were ordered by each customer?
------------------------------------------------------------------------
SELECT
    c.customer_id,
    p.pizza_name,
    COUNT(p.pizza_name) AS pizza_counts
FROM customer_orders_clean AS c
INNER JOIN pizza_names AS p
    ON c.pizza_id = p.pizza_id
GROUP BY
    c.customer_id,
    p.pizza_name
ORDER BY
    c.customer_id ASC,
    p.pizza_name;

------------------------------------------------------------------------
--Q06 What was the maximum number of pizzas delivered in a single order?
------------------------------------------------------------------------
WITH pizza_counts AS (
    SELECT
        c.order_id,
        COUNT(c.order_id) AS counts
    FROM customer_orders_clean AS c
    INNER JOIN runner_orders_clean AS r
        ON c.order_id = r.order_id
    WHERE r.cancellation IS NULL
    GROUP BY c.order_id
)
SELECT
    MAX(counts) AS max_pizza
FROM pizza_counts;

------------------------------------------------------------------------
--Q07 For each customer, how many delivered pizzas had at least 1
--              change and how many had no changes?
------------------------------------------------------------------------
SELECT
    c.customer_id,
    SUM(CASE
            WHEN c.exclusions IS NULL AND c.extras IS NULL
                THEN 1
            ELSE 0 END) AS no_change,
    SUM(CASE
            WHEN c.exclusions IS NOT NULL OR c.extras IS NOT NULL
                THEN 1
            ELSE 0 END) AS with_change
FROM customer_orders_clean AS c
INNER JOIN runner_orders_clean AS r
    ON c.order_id = r.order_id
WHERE r.cancellation IS NULL
GROUP BY
    c.customer_id;

------------------------------------------------------------------------
--Q08 How many pizzas were delivered that had both exclusions and extras?
------------------------------------------------------------------------
SELECT
    COUNT(*) AS order_counts
FROM customer_orders_clean AS c
INNER JOIN runner_orders_clean AS r
    ON r.order_id = c.order_id
WHERE r.cancellation IS NULL
  AND (c.extras IS NOT NULL AND c.exclusions IS NOT NULL);

------------------------------------------------------------------------
--Q09 What was the total volume of pizzas ordered for each hour of the day?
------------------------------------------------------------------------
SELECT
    DATEPART(HOUR, order_time) AS hours_histo,
    COUNT(*) AS counts_pizza
FROM customer_orders_clean
GROUP BY
    DATEPART(HOUR, order_time)
ORDER BY
    hours_histo ASC;

------------------------------------------------------------------------
--Q10 What was the volume of orders for each day of the week?
------------------------------------------------------------------------
SELECT
    DATENAME(WEEKDAY, order_time) AS week_day,
    COUNT(*) AS counts_pizza
FROM customer_orders_clean
GROUP BY
    DATENAME(WEEKDAY, order_time),
    DATEPART(WEEKDAY, order_time)
ORDER BY
    DATEPART(WEEKDAY, order_time) ASC;
