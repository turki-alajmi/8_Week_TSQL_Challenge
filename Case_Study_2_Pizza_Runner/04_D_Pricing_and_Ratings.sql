/* ---------------------------------------------------------------------------
-- Case Study #2: Pizza Runner
-- Section D: Pricing and Ratings
-- Author: Turki Alajmi
-- Date: March 2026
-- Tool used: Microsoft SQL Server (T-SQL)
--------------------------------------------------------------------------- */
------------------------------------------------------------------------
-- Q01: If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and
--      there were no charges for changes — how much money has Pizza
--      Runner made so far if there are no delivery fees?
------------------------------------------------------------------------

SELECT
    SUM(CASE
            WHEN c.pizza_id = 1
                THEN 12
            ELSE 10
        END)
        AS total_rev
FROM customer_orders_clean AS c
INNER JOIN runner_orders_clean AS r
    ON c.order_id = r.order_id
WHERE r.cancellation IS NULL;

------------------------------------------------------------------------
-- Q02: What if there was an additional $1 charge for any pizza extras?
------------------------------------------------------------------------

SELECT
    SUM(CASE
            WHEN c.pizza_id = 1 THEN 12
            ELSE 10
        END) + SUM(total_extra * 1)
        AS total_rev
FROM customer_orders_clean AS c
INNER JOIN runner_orders_clean AS r
    ON c.order_id = r.order_id
CROSS APPLY (
    SELECT
        COUNT(value) AS total_extra
    FROM STRING_SPLIT(c.extras, ',')
) AS splited
WHERE r.cancellation IS NULL;

------------------------------------------------------------------------
-- Q03: The Pizza Runner team now wants to add an additional ratings
--      system that allows customers to rate their runner. Design an
--      additional table for this new dataset — generate a schema for
--      this new table and insert your own data for ratings for each
--      successful customer order between 1 to 5.
------------------------------------------------------------------------
USE pizza_runner;
GO
CREATE TABLE ratings
(
    order_id    INT NOT NULL,
    runner_id   INT NOT NULL,
    customer_id INT NOT NULL,
    rating      INT,
    rating_time DATETIME DEFAULT GETDATE(),
    CONSTRAINT pk_ratings PRIMARY KEY (order_id),
    CONSTRAINT fk_ratings_runner_orders_clean FOREIGN KEY (order_id) REFERENCES runner_orders_clean (order_id),
    CONSTRAINT fk_ratings_runners FOREIGN KEY (runner_id) REFERENCES runners (runner_id),
    CONSTRAINT chk_ratings_rating CHECK (rating BETWEEN 1 AND 5)
)
GO
INSERT INTO pizza_runner.dbo.ratings (order_id, runner_id, customer_id, rating, rating_time)
VALUES (1, 1, 101, 2, N'2021-01-01 23:15:33.000'),
    (2, 1, 101, 4, N'2021-01-01 22:07:54.000'),
    (3, 1, 102, 5, N'2021-01-03 00:12:37.000'),
    (4, 2, 103, 3, N'2021-01-04 13:53:03.000'),
    (5, 3, 104, 1, N'2021-01-09 21:10:57.000'),
    (7, 2, 105, 1, N'2021-01-11 21:30:45.000'),
    (8, 2, 102, 5, N'2021-01-10 07:15:02.000'),
    (10, 1, 104, 5, N'2021-01-11 19:59:20.000');
------------------------------------------------------------------------
-- Q04: Using your newly generated table — join all of the information
--      together to form a table for successful deliveries including:
--      customer_id, order_id, runner_id, rating, order_time,
--      pickup_time, time between order and pickup, delivery duration,
--      average speed, total number of pizzas.
------------------------------------------------------------------------

/*
 Note: No cancellation filter needed — the ratings table only contains
 successful deliveries by design.
*/
WITH pizza_counts AS (
    SELECT
        order_id,
        COUNT(order_id) AS total_number_of_pizzas
    FROM customer_orders_clean
    GROUP BY
        order_id
)

SELECT DISTINCT
    rt.customer_id,
    rt.order_id,
    rt.runner_id,
    rt.rating,
    c.order_time,
    r.pickup_time,
    DATEDIFF(MINUTE, c.order_time, r.pickup_time) AS order_pick_diff,
    r.duration,
    CAST(r.distance / (r.duration / 60.0) AS DECIMAL(5, 1)) AS avg_speed_kmph,
    pc.total_number_of_pizzas
FROM ratings AS rt
INNER JOIN runner_orders_clean AS r
    ON rt.order_id = r.order_id
INNER JOIN customer_orders_clean AS c
    ON rt.order_id = c.order_id
INNER JOIN pizza_counts AS pc
    ON pc.order_id = rt.order_id;

------------------------------------------------------------------------
-- Q05: If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices
--      with no cost for extras and each runner is paid $0.30 per
--      kilometre travelled — how much money does Pizza Runner have
--      left over after these deliveries?
------------------------------------------------------------------------

WITH runner_salary AS (
    SELECT
        SUM(distance * 0.3) AS total_runner_salaries
    FROM runner_orders_clean
    WHERE cancellation IS NULL
)

SELECT
    SUM(CASE
            WHEN c.pizza_id = 1
                THEN 12
            ELSE 10
        END) - MAX(total_runner_salaries)
        AS total_rev
FROM customer_orders_clean AS c
INNER JOIN runner_orders_clean AS r
    ON c.order_id = r.order_id
CROSS JOIN runner_salary
WHERE r.cancellation IS NULL;