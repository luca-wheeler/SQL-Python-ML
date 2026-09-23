-- 02_checks.sql
-- Data quality checks for raw.bureau after loading (02_load_bureau.sql).
-- Run: docker compose exec -T db psql -U luca -d credit_risk < sql/02_checks.sql
-- Every "Expected" value below was computed directly from bureau.csv.

-- 1. Row count
-- Expected: 1,716,428 (wc -l on the CSV minus 1 header line)
SELECT COUNT(*) AS total_rows
FROM raw.bureau;

-- 2. Is sk_id_bureau a unique key? (one row per bureau loan)
-- Expected: distinct_bureau_ids = total_rows = 1,716,428
SELECT
    COUNT(*)                      AS total_rows,
    COUNT(DISTINCT sk_id_bureau)  AS distinct_bureau_ids
FROM raw.bureau;

-- 3. NULL count per column
-- Expected: only these 7 columns have NULLs:
--   days_credit_enddate 105,553 | days_enddate_fact 633,653
--   amt_credit_max_overdue 1,124,488 | amt_credit_sum 13
--   amt_credit_sum_debt 257,669 | amt_credit_sum_limit 591,780
--   amt_annuity 1,226,791
SELECT
    COUNT(*)                                  AS total_rows,
    COUNT(*) - COUNT(sk_id_curr)              AS sk_id_curr_nulls,
    COUNT(*) - COUNT(sk_id_bureau)            AS sk_id_bureau_nulls,
    COUNT(*) - COUNT(credit_active)           AS credit_active_nulls,
    COUNT(*) - COUNT(credit_currency)         AS credit_currency_nulls,
    COUNT(*) - COUNT(days_credit)             AS days_credit_nulls,
    COUNT(*) - COUNT(credit_day_overdue)      AS credit_day_overdue_nulls,
    COUNT(*) - COUNT(days_credit_enddate)     AS days_credit_enddate_nulls,
    COUNT(*) - COUNT(days_enddate_fact)       AS days_enddate_fact_nulls,
    COUNT(*) - COUNT(amt_credit_max_overdue)  AS amt_credit_max_overdue_nulls,
    COUNT(*) - COUNT(cnt_credit_prolong)      AS cnt_credit_prolong_nulls,
    COUNT(*) - COUNT(amt_credit_sum)          AS amt_credit_sum_nulls,
    COUNT(*) - COUNT(amt_credit_sum_debt)     AS amt_credit_sum_debt_nulls,
    COUNT(*) - COUNT(amt_credit_sum_limit)    AS amt_credit_sum_limit_nulls,
    COUNT(*) - COUNT(amt_credit_sum_overdue)  AS amt_credit_sum_overdue_nulls,
    COUNT(*) - COUNT(credit_type)             AS credit_type_nulls,
    COUNT(*) - COUNT(days_credit_update)      AS days_credit_update_nulls,
    COUNT(*) - COUNT(amt_annuity)             AS amt_annuity_nulls
FROM raw.bureau;

-- 4. Does a missing actual end date just mean "loan still open"?
-- Expected: Active 628,638 | Closed 125 | Sold 4,879 | Bad debt 11
-- So nearly all NULL days_enddate_fact rows are Active loans (not ended yet):
-- the NULL carries meaning, it isn't random missing data.
SELECT
    credit_active,
    COUNT(*)                                AS loans,
    COUNT(*) - COUNT(days_enddate_fact)     AS missing_end_date
FROM raw.bureau
GROUP BY credit_active
ORDER BY loans DESC;

-- 5. Category values
-- Expected credit_active: Closed 1,079,273 | Active 630,607 | Sold 6,527 | Bad debt 21
SELECT credit_active, COUNT(*) AS loans
FROM raw.bureau
GROUP BY credit_active
ORDER BY loans DESC;

-- Expected credit_currency: currency 1 = 1,715,020 (99.9%); currencies 2-4 are rare
SELECT credit_currency, COUNT(*) AS loans
FROM raw.bureau
GROUP BY credit_currency
ORDER BY loans DESC;

-- Expected credit_type: 15 types; Consumer credit 1,251,615 and
-- Credit card 402,195 dominate; several types have fewer than 100 rows
SELECT credit_type, COUNT(*) AS loans
FROM raw.bureau
GROUP BY credit_type
ORDER BY loans DESC;

-- 6. Whole-number checks: days and count columns loaded as NUMERIC.
-- Expected: 0 for every column, so all can be cast to INTEGER in cleaning.
-- NULLs are skipped (NULL <> x is NULL, not true), which is what we want.
SELECT
    COUNT(*) FILTER (WHERE days_credit         <> TRUNC(days_credit))         AS days_credit_non_whole,
    COUNT(*) FILTER (WHERE credit_day_overdue  <> TRUNC(credit_day_overdue))  AS credit_day_overdue_non_whole,
    COUNT(*) FILTER (WHERE days_credit_enddate <> TRUNC(days_credit_enddate)) AS days_credit_enddate_non_whole,
    COUNT(*) FILTER (WHERE days_enddate_fact   <> TRUNC(days_enddate_fact))   AS days_enddate_fact_non_whole,
    COUNT(*) FILTER (WHERE days_credit_update  <> TRUNC(days_credit_update))  AS days_credit_update_non_whole,
    COUNT(*) FILTER (WHERE cnt_credit_prolong  <> TRUNC(cnt_credit_prolong))  AS cnt_credit_prolong_non_whole
FROM raw.bureau;

-- 7. Timeline sanity: DAYS_* are relative to the application date (day 0).
-- Expected:
--   days_credit (loan start)        min -2,922  max 0      -> always in the past, good
--   days_credit_enddate (planned)   max 31,199             -> future end dates are normal
--   days_enddate_fact (actual end)  max 0                  -> never in the future, good
--   days_credit_update              17 rows > 0, max 372   -> updated AFTER the application!
-- Those 17 rows describe the future relative to the application; a possible
-- leakage source. Note them now and decide how to treat them in cleaning.
SELECT
    MIN(days_credit)                                   AS days_credit_min,
    MAX(days_credit)                                   AS days_credit_max,
    MAX(days_credit_enddate)                           AS days_credit_enddate_max,
    MAX(days_enddate_fact)                             AS days_enddate_fact_max,
    COUNT(*) FILTER (WHERE days_credit_update > 0)     AS updates_after_application,
    MAX(days_credit_update)                            AS days_credit_update_max
FROM raw.bureau;

-- 8. Grain: how many bureau loans per applicant?
-- Expected: 305,811 distinct applicants; the busiest has 116 loans.
-- This is why bureau MUST be aggregated to one row per applicant before
-- joining to application_train, or the join would duplicate applicants.
WITH loans_per_applicant AS (
    SELECT sk_id_curr, COUNT(*) AS n_loans
    FROM raw.bureau
    GROUP BY sk_id_curr
)
SELECT
    COUNT(*)      AS distinct_applicants,
    MIN(n_loans)  AS min_loans,
    MAX(n_loans)  AS max_loans,
    ROUND(AVG(n_loans), 2) AS avg_loans
FROM loans_per_applicant;

-- 9. Coverage: how many application_train applicants have a bureau record?
-- (Run after 03_load_application.sql.)
-- Expected: 263,491 of 307,511 (about 86%). The other 44,020 have no bureau
-- history at all, so their bureau features will be NULL after a LEFT JOIN.
-- The 42,320 bureau applicants NOT in train belong to application_test.
-- How it works: first shrink bureau to one row per applicant (the CTE), then
-- LEFT JOIN it on. Applicants with no bureau history get NULL in b.sk_id_curr,
-- and COUNT(b.sk_id_curr) skips NULLs, so it counts only the matches.
-- (A "WHERE sk_id_curr IN (SELECT ... FROM raw.bureau)" inside COUNT looks
-- simpler, but Postgres can end up re-scanning all 1.7M bureau rows for
-- every applicant, and it effectively never finishes.)
WITH bureau_applicants AS (
    SELECT DISTINCT sk_id_curr
    FROM raw.bureau
)
SELECT
    COUNT(*)             AS train_applicants,
    COUNT(b.sk_id_curr)  AS with_bureau_history
FROM raw.application_train AS a
LEFT JOIN bureau_applicants AS b
    ON b.sk_id_curr = a.sk_id_curr;
