-- ==========================================================================================
-- customer_orders >>> customer_orders_clean
-- ==========================================================================================
-- 1. Standardizes 'null' text, 'nan', and empty strings ('') into true SQL NULL values.
-- 2. Strips trailing/leading spaces from string columns.
-- 3. Materializes the clean data into a permanent table for analysis.
-- ==========================================================================================
SELECT
    order_id,
    customer_id,
    pizza_id,
    CAST(CASE
             WHEN TRIM(LOWER(exclusions)) IN ('null', '', 'nan')
                 THEN NULL
             ELSE REPLACE(exclusions, ' ', '')
        END
        AS VARCHAR(50)) AS exclusions,
    CAST(CASE
             WHEN TRIM(LOWER(extras)) IN ('null', '', 'nan')
                 THEN NULL
             ELSE REPLACE(extras, ' ', '')
        END
        AS VARCHAR(50)) AS extras,
    order_time
INTO customer_orders_clean
FROM customer_orders;

-- ==========================================================================================
-- runner_orders >>> runner_orders_clean
-- ==========================================================================================
-- 1. Standardizes 'null' text, 'nan', and empty strings ('') into true SQL NULL values.
-- 2. Dynamically extracts numeric values from strings (stripping 'km', 'mins', 'minutes').
-- 3. Enforces strict data typing (DATETIME for timestamps, FLOAT for distance, INT for duration).
-- 4. Materializes the clean data into a permanent table for analysis.
-- ==========================================================================================
WITH nulling AS (
    SELECT
        order_id,
        runner_id,
        CASE
            WHEN TRIM(LOWER(pickup_time)) IN ('null', 'nan', '')
                THEN NULL
            ELSE pickup_time
            END AS pickup_time,
        CASE
            WHEN TRIM(LOWER(distance)) IN ('null', 'nan', '')
                THEN NULL
            ELSE distance
            END AS distance,
        CASE
            WHEN TRIM(LOWER(duration)) IN ('null', 'nan', '')
                THEN NULL
            ELSE duration
            END AS duration,
        CASE
            WHEN TRIM(LOWER(cancellation)) IN ('null', 'nan', '')
                THEN NULL
            ELSE cancellation
            END AS cancellation
    FROM runner_orders
),
    string_fix AS (
        SELECT
            order_id,
            runner_id,
            pickup_time,
            TRIM(REPLACE(LOWER(distance), 'km', '')) AS distance,
            CASE
                WHEN PATINDEX('%m%', duration) > 0
                    THEN TRIM(LEFT(duration, (PATINDEX('%m%', duration)) - 1))
                ELSE TRIM(duration)
                END AS duration,
            --Dynamically extracts the number by slicing everything to the left of 'm' (handles both 'mins' and 'minutes' etc.)
            cancellation

        FROM nulling
    )
SELECT
    order_id,
    runner_id,
    CAST(pickup_time AS DATETIME) AS pickup_time,
    CAST(distance AS DECIMAL(5, 1)) AS distance,
    CAST(duration AS INTEGER) AS duration,
    cancellation
INTO runner_orders_clean
FROM string_fix;
