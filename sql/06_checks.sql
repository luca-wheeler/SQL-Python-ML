-- 06_checks.sql
-- Tests that features.bureau_by_applicant (built by 06_agg_bureau.sql) is right.
-- Run: docker compose exec -T db psql -U luca -d credit_risk -v ON_ERROR_STOP=1 < sql/06_checks.sql
-- Each check compares the feature table with the raw table, after the days_credit_update <= 0 filter.
-- The checks fall into four groups:
--   1      shape: one row per applicant?
--   2      totals: did grouping lose or invent any loan rows?
--   3      ranges: do the formulas give sensible values?
--   4      hand-check: does one real applicant match an independent recompute?

\timing on

-- 1. Check row count and that applicants are distinct
-- Expect: total_rows 305810, distinct_applicants 305810 (must match)
SELECT
    COUNT(*)                   AS total_rows,
    COUNT(DISTINCT sk_id_curr) AS distinct_applicants
FROM features.bureau_by_applicant;

-- 2. Check grouping neither created nor destroyed loan rows
-- Expect: total_loans 1716411, total_active 630590, total_bad 6548,
--         total_debt_unknown 73547, total_overdue 65074518.945
-- total_loans is the raw 1716428 minus the 17 rows dropped by days_credit_update <= 0
-- total_debt_unknown is the 73547 found in the first NULL-debt check on raw.bureau
SELECT
    SUM(bur_n_loans)          AS total_loans,
    SUM(bur_n_active)         AS total_active,
    SUM(bur_n_bad)            AS total_bad,
    SUM(bur_n_debt_unknown)   AS total_debt_unknown,
    SUM(bur_total_overdue)    AS total_overdue
FROM features.bureau_by_applicant;

-- 3a. Check counts are consistent with each other and no feature has an impossible sign
-- Expect: all four columns 0
-- A subset can never be larger than its whole: unknown <= active <= loans
-- bur_days_since_last is -MAX(days_credit) and days_credit is negative, so it must be 0 or above
SELECT
    COUNT(*) FILTER (WHERE bur_n_debt_unknown > bur_n_active) AS unknown_above_active,
    COUNT(*) FILTER (WHERE bur_n_active > bur_n_loans)        AS active_above_loans,
    COUNT(*) FILTER (WHERE bur_days_since_last < 0)           AS negative_days_since_last,
    COUNT(*) FILTER (WHERE bur_max_days_overdue < 0)          AS negative_days_overdue
FROM features.bureau_by_applicant;

-- 3b. Check the debt ratio varies and see where it is NULL
-- Expect: ratio_min -309.0900, ratio_max 382.5100 (they must differ),
--         ratio_null 70109 = null_no_active 54001 + null_has_active 16108
-- min = max = 1.0000 means the denominator used the debt column (debt / debt), which happened once
-- null_has_active applicants have active loans but all debts unknown, or known credit summing to 0
SELECT
    MIN(bur_debt_ratio)                                                AS ratio_min,
    MAX(bur_debt_ratio)                                                AS ratio_max,
    COUNT(*) FILTER (WHERE bur_debt_ratio IS NULL)                     AS ratio_null,
    COUNT(*) FILTER (WHERE bur_debt_ratio IS NULL
                        AND bur_n_active = 0)                          AS null_no_active,
    COUNT(*) FILTER (WHERE bur_debt_ratio IS NULL
                        AND bur_n_active > 0)                          AS null_has_active
FROM features.bureau_by_applicant;

-- 3c. Check the tails of the debt ratio
-- Expect: ratio_above_1 6993, ratio_negative 815
-- Negatives come from 8418 raw loans with negative amt_credit_sum_debt (credit balances)
-- Not errors in the aggregation; clipping is handled in Python (see DECISIONS.md)
SELECT
    COUNT(*) FILTER (WHERE bur_debt_ratio > 1) AS ratio_above_1,
    COUNT(*) FILTER (WHERE bur_debt_ratio < 0) AS ratio_negative
FROM features.bureau_by_applicant;

-- 4. Check applicant 100016: feature row vs a recompute from the raw loans
-- Expect: the two rows show identical numbers in every column
-- 100016 has 7 loans, 4 active, and at least one active loan with unknown debt
-- The recompute uses CASE and SUM instead of FILTER, so it is not a copy of the feature code
SELECT
    'feature' AS source,
    bur_n_loans, bur_n_active, bur_n_bad, bur_n_debt_unknown,
    bur_active_debt, bur_active_credit, bur_debt_ratio,
    bur_max_days_overdue, bur_total_overdue, bur_days_since_last
FROM features.bureau_by_applicant
WHERE sk_id_curr = 100016
UNION ALL
SELECT
    'recompute',
    COUNT(*),
    SUM(CASE WHEN credit_active = 'Active' THEN 1 ELSE 0 END),
    SUM(CASE WHEN credit_active IN ('Bad debt', 'Sold') THEN 1 ELSE 0 END),
    SUM(CASE WHEN credit_active = 'Active' AND amt_credit_sum_debt IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN credit_active = 'Active' THEN amt_credit_sum_debt END),
    SUM(CASE WHEN credit_active = 'Active' THEN amt_credit_sum END),
    ROUND(
        SUM(CASE WHEN credit_active = 'Active' AND amt_credit_sum_debt IS NOT NULL
                 THEN amt_credit_sum_debt END)
        / NULLIF(SUM(CASE WHEN credit_active = 'Active' AND amt_credit_sum_debt IS NOT NULL
                          THEN amt_credit_sum END), 0),
        4),
    MAX(credit_day_overdue),
    SUM(amt_credit_sum_overdue),
    -MAX(days_credit)
FROM raw.bureau
WHERE sk_id_curr = 100016
  AND days_credit_update <= 0;
