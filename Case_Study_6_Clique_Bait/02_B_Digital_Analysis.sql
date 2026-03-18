/* ---------------------------------------------------------------------------
-- Case Study #6: Clique Bait
-- Section B: Digital Analysis
-- Author: Turki Alajmi
-- Date: March 2026
-- Tool used: Microsoft SQL Server (T-SQL)
--------------------------------------------------------------------------- */

------------------------------------------------------------------------
-- Q1: How many users are there?
------------------------------------------------------------------------

SELECT
    COUNT(DISTINCT user_id) AS user_count
FROM clique_bait.users;

------------------------------------------------------------------------
-- Q2: How many cookies does each user have on average?
------------------------------------------------------------------------

SELECT
    COUNT(cookie_id) AS cookie_counts,
    COUNT(DISTINCT user_id) AS user_counts,
    (COUNT(DISTINCT cookie_id) * 1.0) / COUNT(DISTINCT user_id) avg_cookie
FROM clique_bait.users;

------------------------------------------------------------------------
-- Q3: What is the unique number of visits by all users per month?
------------------------------------------------------------------------

SELECT
    DATENAME(MONTH, event_time) AS month,
    COUNT(DISTINCT visit_id) visit_count
FROM clique_bait.events
GROUP BY
    DATENAME(MONTH, event_time),
    DATEPART(MONTH, event_time)
ORDER BY
    DATEPART(MONTH, event_time);

------------------------------------------------------------------------
-- Q4: What is the number of events for each event type?
------------------------------------------------------------------------

SELECT
    i.event_name,
    COUNT(*) as event_count
FROM clique_bait.events AS e
INNER JOIN clique_bait.event_identifier AS i
    ON i.event_type = e.event_type
GROUP BY
    i.event_name;

------------------------------------------------------------------------
-- Q5: What is the percentage of visits which have a purchase event?
------------------------------------------------------------------------

WITH purchases AS (
    SELECT
        COUNT(DISTINCT visit_id) AS unique_visits_counts,
        COUNT(DISTINCT CASE WHEN event_type = 3 THEN visit_id END) AS purchase_counts
    FROM clique_bait.events
)

SELECT
    CAST((purchase_counts * 100.0) / unique_visits_counts AS DECIMAL(5, 2)) AS purchase_percentage
FROM purchases;

------------------------------------------------------------------------
-- Q6: What is the percentage of visits which view the checkout page
-- but do not have a purchase event?
------------------------------------------------------------------------
-- NOTE: The grammatical grain of this question is ambiguous.
-- I have provided two queries to answer both possible business metrics.

/*
 Interpretation 1: Denominator = all site visits (consistent with Q5 framework)
 Formula: visits that viewed checkout without purchasing / total visits
*/

WITH cte AS (
    SELECT
        COUNT(DISTINCT visit_id) AS view_checkout_non_purchase
    FROM clique_bait.events AS e1
    WHERE event_type = 1
      AND page_id = 12
      AND NOT EXISTS(
        SELECT
            e2.visit_id
        FROM clique_bait.events AS e2
        WHERE e2.visit_id = e1.visit_id
          AND e2.event_type = 3
    )
)
SELECT
    CAST((MAX(view_checkout_non_purchase) * 100.0)
        /
         COUNT(DISTINCT visit_id) AS DECIMAL(5, 2)) AS checkout_no_purchase
FROM clique_bait.events
CROSS JOIN cte;

/*
 Interpretation 2: Denominator = visits that reached checkout (standard e-commerce abandonment rate)
 Formula: visits that viewed checkout without purchasing / visits that viewed checkout
*/

WITH cte AS (
    SELECT
        COUNT(DISTINCT visit_id) AS view_checkout_non_purchase
    FROM clique_bait.events AS e1
    WHERE event_type = 1
      AND page_id = 12
      AND NOT EXISTS(
        SELECT
            e2.visit_id
        FROM clique_bait.events AS e2
        WHERE e2.visit_id = e1.visit_id
          AND e2.event_type = 3
    )
)
SELECT
    CAST((MAX(view_checkout_non_purchase) * 100.0)
        /
         COUNT(DISTINCT CASE WHEN page_id = 12 THEN visit_id END) AS DECIMAL(5, 2)) AS checkout_no_purchase
FROM clique_bait.events
CROSS JOIN cte;

------------------------------------------------------------------------
-- Q7: What are the top 3 pages by number of views?
------------------------------------------------------------------------
SELECT TOP 3
    page_name,
    COUNT(*) view_count
FROM clique_bait.events AS e
INNER JOIN clique_bait.page_hierarchy AS h
    ON h.page_id = e.page_id
WHERE event_type = 1
GROUP BY
    page_name
ORDER BY
    view_count DESC;

------------------------------------------------------------------------
-- Q8: What is the number of views and cart adds for each product category?
------------------------------------------------------------------------

SELECT
    product_category,
    SUM(CASE WHEN event_type = 1 THEN 1 ELSE 0 END) AS view_count,
    SUM(CASE WHEN event_type = 2 THEN 1 ELSE 0 END) AS add_cart_count
FROM clique_bait.events AS e
INNER JOIN clique_bait.page_hierarchy AS h
    ON h.page_id = e.page_id
WHERE product_category IS NOT NULL
GROUP BY
    product_category;

------------------------------------------------------------------------
-- Q9: What are the top 3 products by purchases?
------------------------------------------------------------------------

WITH cte AS (
    SELECT
        visit_id,
        page_id
    FROM clique_bait.events AS e1
    WHERE event_type = 2
      AND EXISTS(
        SELECT
            e2.visit_id
        FROM clique_bait.events AS e2
        WHERE e1.visit_id = e2.visit_id
          AND e2.event_type = 3
    )
)
SELECT TOP 3
    page_name,
    COUNT(*) AS purchase_count
FROM cte
INNER JOIN clique_bait.page_hierarchy AS h
    ON h.page_id = cte.page_id
GROUP BY
    page_name
ORDER BY
    purchase_count DESC;