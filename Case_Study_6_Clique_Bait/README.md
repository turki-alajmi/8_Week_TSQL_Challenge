# 🛒 Case Study #5: Data Mart

> 🔗 **Check out the original challenge prompt and dataset here:** [Case Study #5: Data Mart](https://8weeksqlchallenge.com/case-study-5/)

## 📋 Table of Contents
- [The Business Problem](#-the-business-problem)
- [Tech Stack & Skills Applied](#%EF%B8%8F-tech-stack--skills-applied)
- [Entity Relationship Diagram](#%EF%B8%8F-entity-relationship-diagram)
- [Data Cleansing & Issues Found](#-data-cleansing--issues-found)
- [Highlight Queries & Engineering Logic](#-highlight-queries--engineering-logic)
- [What I Would Do Differently in Production](#%EF%B8%8F-what-i-would-do-differently-in-production)

---

## 🏢 The Business Problem

Danny runs **Data Mart** — an international online supermarket that specialises in fresh produce. In June 2020, the business introduced sustainable packaging across all products. The business needed to know: **did the change hurt sales, and if so, where?**

**The Goal:**
The source data arrived as a single pre-aggregated table with dates stored as `VARCHAR` in a non-standard format and no analytical dimensions derived. Before any analysis could run, the raw table required a full cleansing pipeline to parse dates, derive week numbers, map segment codes to readable labels, and materialize a clean table. From there, the objective was to quantify the before/after sales impact of the packaging change across time periods, regions, platforms, demographics, and customer types.

---

## 🛠️ Tech Stack & Skills Applied

- **Database Engine:** SQL Server (T-SQL)
- **Data Engineering Skills Applied:**
  - **Data Cleansing:** `CONVERT` with style codes, `CASE WHEN` segment mapping, `SELECT INTO`
  - **Date Engineering:** VARCHAR date parsing, week number derivation via integer division bucketing
  - **Before/After Impact Analysis:** `DATEADD` boundary windows, `CROSS JOIN` scalar aggregation
  - **Multi-Dimension Aggregation:** `GROUPING SETS`, `GROUPING()` for NULL disambiguation
  - **Overflow Handling:** `BIGINT` casting on large sales aggregations

---

## 🗄️ Entity Relationship Diagram

![Case5_ERD.png](Case5_ERD.png)

---

## 🧹 Data Cleansing & Issues Found

*Full cleansing script: [01_A_Data_Cleansing_Steps.sql](01_A_Data_Cleansing_Steps.sql)*

All cleansing and dimension derivation was performed in a single query using a CTE, then materialized into `data_mart.clean_weekly_sales` via `SELECT INTO`.

| Column | Issue Found | Fix Applied |
| :--- | :--- | :--- |
| `week_date` | Stored as `VARCHAR(7)` in `dd/mm/yy` format | `CONVERT(DATE, week_date, 3)` — style code 3 handles the non-standard format |
| `week_date` | No `week_number` column existed | `((DATEPART(DAYOFYEAR, week_date) - 1) / 7) + 1` — integer division buckets days into 7-day periods from Jan 1 |
| `segment` | Literal `'null'` string instead of `NULL` | `CASE WHEN segment = 'null' THEN 'unknown'` |
| `segment` | No `age_band` or `demographic` columns existed | `LEFT(segment, 1)` extracts demographic letter; `RIGHT(segment, 1)` extracts age number — both mapped via `CASE WHEN` |
| `sales` | Stored as `INT` — overflows on `SUM` across 17k rows | `CAST(sales AS BIGINT)` before every aggregation |

---

## 💡 Highlight Queries & Engineering Logic

### Highlight 1 — Set Subtraction: Finding Missing Week Numbers with Recursive CTE + EXCEPT
**Question:** *Section B, Q2 — What range of week numbers are missing from the dataset?*
*Full script: [02_B_Data_Exploration.sql](02_B_Data_Exploration.sql)*

**The Problem:** The dataset only covers a trading window within each year — not the full 52 weeks. To find the missing week numbers, a complete reference set of all possible weeks is needed to compare against. That reference doesn't exist in the data — it has to be generated.

**The Solution:** A recursive CTE generates integers 1 through 52 as the complete reference set. `EXCEPT` subtracts the week numbers that exist in the dataset, leaving only the gaps. This is the standard T-SQL approach for generating a number sequence when a tally table isn't available — `GENERATE_SERIES(1, 52)` achieves the same result on SQL Server 2022+.
```sql
-- Recursive CTE : generate rows numbered from 1 to 52, acts as weeks in a year
-- Note: GENERATE_SERIES(1, 52) can replace this CTE on SQL Server 2022+
WITH all_possible_weeks AS (
    SELECT
        1 AS missing_week_number
    UNION ALL
    SELECT
        missing_week_number + 1
    FROM all_possible_weeks
    WHERE missing_week_number < 52
)
SELECT
    missing_week_number
FROM all_possible_weeks

-- Using EXCEPT to subtract existing week numbers, leaving only the gaps
EXCEPT

SELECT
    week_number
FROM data_mart.clean_weekly_sales;
```

<details>
<summary><b>📊 Click to expand Result Set</b></summary>


| missing\_week\_number |
| :--- |
| 1 |
| 2 |
| 3 |
| 4 |
| 5 |
| 6 |
| 7 |
| 8 |
| 9 |
| 10 |
| 11 |
| 37 |
| 38 |
| 39 |
| 40 |
| 41 |
| 42 |
| 43 |
| 44 |
| 45 |
| 46 |
| 47 |
| 48 |
| 49 |
| 50 |
| 51 |
| 52 |

</details>

---

### Highlight 2 — Before/After Impact Analysis with `DATEADD` Boundaries
**Question:** *Section C, Q1 — What is the total sales for the 4 weeks before and after `2020-06-15`? What is the growth or reduction rate in actual values and percentage of sales?*
*Full script: [03_C_Before_After_Analysis.sql](03_C_Before_After_Analysis.sql)*

**The Problem:** Measuring the sales impact of the packaging change required splitting the dataset into two precise windows around a specific baseline date. Danny's grain explicitly includes `2020-06-15` as the start of the after period — so the boundary logic needed to reflect that exactly.

**The Solution:** Two CTEs each aggregate one window using `DATEADD` to define the boundaries relative to the baseline date. A `CROSS JOIN` between the two scalar CTEs brings both totals onto one row for inline difference and growth calculation. `CAST(sales AS BIGINT)` is applied before `SUM` to prevent integer overflow on the large aggregations.

```sql
WITH before_4_weeks AS (
    SELECT
        SUM(CAST(sales AS BIGINT)) AS before_sales
    FROM data_mart.clean_weekly_sales
    WHERE week_date < '20200615'
      AND week_date >= DATEADD(WEEK, -4, '20200615')
),
    after_4_weeks AS (
        SELECT
            SUM(CAST(sales AS BIGINT)) AS after_sales
        FROM data_mart.clean_weekly_sales
        WHERE week_date >= '20200615'
          AND week_date < DATEADD(WEEK, 4, '20200615')
    )

SELECT
    before_sales,
    after_sales,
    after_sales - before_sales AS sales_difference,
    CAST(((after_sales - before_sales) * 100.0) / before_sales AS DECIMAL(5, 2)) AS growth
FROM before_4_weeks
CROSS JOIN after_4_weeks;
```

#### 📊 Result Set

| before\_sales | after\_sales | sales\_difference | growth |
| :--- | :--- | :--- | :--- |
| 2345878357 | 2318994169 | -26884188 | -1.15 |


---

### Highlight 3 — Multi-Dimension Impact Analysis via `GROUPING SETS`
**Question:** *Section D, Q1 — Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12-week before and after period? Analyse by: `region`, `platform`, `age_band`, `demographic`, `customer_type`.*
*Full script: [04_D_Bonus_Questions.sql](04_D_Bonus_Questions.sql)*

**The Problem:** Running the same before/after analysis across 5 separate dimensions would typically require 5 separate queries or a `UNION ALL` block — duplicating the same aggregation logic 5 times and scanning the table 5 times. Additionally, the standard `NULL` produced by `GROUPING SETS` for non-grouped columns is ambiguous — it could mean the column wasn't part of the grouping, or it could mean the underlying data is null.

**The Solution:** `GROUPING SETS` runs all 5 groupings in a single table scan. Each dimension is listed as its own set — `(region), (platform), ...` — so they remain independent rather than being combined. `GROUPING(column)` returns `1` when a column was not part of the current grouping level, allowing the ambiguous `NULL` to be replaced with `'-'` as a clear visual marker. The result is a single output table that a reviewer can immediately parse by dimension.

```sql
-- Groups sales by 5 business dimensions using GROUPING SETS for a single-scan analysis.
-- GROUPING() replaces aggregation NULLs with '-' to distinguish them from data NULLs.

WITH before_after_sales AS (
    SELECT
        CASE WHEN GROUPING(region) = 1 THEN '-' ELSE region END AS region,
        CASE WHEN GROUPING(platform) = 1 THEN '-' ELSE platform END AS platform,
        CASE WHEN GROUPING(age_band) = 1 THEN '-' ELSE age_band END AS age_band,
        CASE WHEN GROUPING(demographic) = 1 THEN '-' ELSE demographic END AS demographic,
        CASE WHEN GROUPING(customer_type) = 1 THEN '-' ELSE customer_type END AS customer_type,
        SUM(CASE
                WHEN week_number BETWEEN 12 AND 23 THEN
                    CAST(sales AS BIGINT) END) AS before_sales,
        SUM(CASE
                WHEN week_number BETWEEN 24 AND 35 THEN
                    CAST(sales AS BIGINT) END) AS after_sales
    FROM data_mart.clean_weekly_sales
    WHERE week_number BETWEEN 12 AND 35
      AND calendar_year = 2020
    GROUP BY
        GROUPING SETS (
        (region), (platform), (age_band), (demographic), (customer_type))
)

SELECT
    region,
    platform,
    age_band,
    demographic,
    customer_type,
    before_sales,
    after_sales,
    after_sales - before_sales AS difference,
    CAST(((after_sales - before_sales) * 100.0) / before_sales AS DECIMAL(5, 2)) AS growth
FROM before_after_sales;
```

<details>
<summary><b>📊 Click to expand Result Set</b></summary>

| region | platform | age\_band | demographic | customer\_type | before\_sales | after\_sales | difference | growth |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| - | - | - | - | Existing | 3690116427 | 3606243454 | -83872973 | -2.27 |
| - | - | - | - | Guest | 2573436301 | 2496233635 | -77202666 | -3.00 |
| - | - | - | - | New | 862720419 | 871470664 | 8750245 | 1.01 |
| - | - | - | Couples | - | 2033589643 | 2015977285 | -17612358 | -0.87 |
| - | - | - | Families | - | 2328329040 | 2286009025 | -42320015 | -1.82 |
| - | - | Middle Aged | - | - | 1164847640 | 1141853348 | -22994292 | -1.97 |
| - | - | Retirees | - | - | 2395264515 | 2365714994 | -29549521 | -1.23 |
| - | - | unknown | - | - | 2764354464 | 2671961443 | -92393021 | -3.34 |
| - | - | Young Adults | - | - | 801806528 | 794417968 | -7388560 | -0.92 |
| - | Retail | - | - | - | 6906861113 | 6738777279 | -168083834 | -2.43 |
| - | Shopify | - | - | - | 219412034 | 235170474 | 15758440 | 7.18 |
| AFRICA | - | - | - | - | 1709537105 | 1700390294 | -9146811 | -0.54 |
| ASIA | - | - | - | - | 1637244466 | 1583807621 | -53436845 | -3.26 |
| CANADA | - | - | - | - | 426438454 | 418264441 | -8174013 | -1.92 |
| EUROPE | - | - | - | - | 108886567 | 114038959 | 5152392 | 4.73 |
| OCEANIA | - | - | - | - | 2354116790 | 2282795690 | -71321100 | -3.03 |
| SOUTH AMERICA | - | - | - | - | 213036207 | 208452033 | -4584174 | -2.15 |
| USA | - | - | - | - | 677013558 | 666198715 | -10814843 | -1.60 |

</details>

> **Key Finding:** The `unknown` demographic and age_band segments recorded the highest negative impact at -3.34%, followed by ASIA (-3.26%) and OCEANIA (-3.03%). Unidentified customers and customers in distant regions were disproportionately affected by the packaging change.

---

## ⚙️ What I Would Do Differently in Production

- The cleansing pipeline runs as a one-time `SELECT INTO` — in production, `clean_weekly_sales` would be a pre-defined table with explicit data types, constraints, and indexes, refreshed incrementally as new weekly data arrives rather than rebuilt from scratch
- `BIGINT` casting is applied at query time to work around the source column being `INT` — in production the column would be defined as `BIGINT` at the schema level, eliminating the need for per-query casting
- The before/after analysis uses a fixed baseline date — in production this would be a parameter passed into a stored procedure, making the analysis reusable for any future event date without modifying query logic

---

[👉 Click here to view the complete SQL scripts for all 4 sections](.)