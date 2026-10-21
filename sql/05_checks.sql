-- 05_checks.sql
-- Tests that features.installments_by_applicant (built by 05_agg_installments.sql) is right.
-- Run: docker compose exec -T db psql -U luca -d credit_risk -v ON_ERROR_STOP=1 < sql/05_checks.sql
-- Each check compares the feature table with what 01_checks.sql found in the raw table.
-- The checks fall into four groups:
--   1      shape: one row per applicant?
--   2      totals: did grouping lose or invent any payment rows?
--   3      ranges: do the formulas give sensible values?
--   4      hand-check: does one real applicant match an independent recompute?

\timing on

-- 1. Check row count and that applicants are distinct
-- Expect: total_rows 339587, distinct_applicants 339587 (must match)
SELECT
    COUNT(*)                   AS total_rows,
    COUNT(DISTINCT sk_id_curr) AS distinct_applicants
FROM features.installments_by_applicant;

-- 2. Check grouping neither created nor destroyed payment rows
-- Expect: total_payments 13605401, total_missed 2905
-- These are the raw row count and the raw count of never-paid rows from 01_checks.sql
SELECT
    SUM(inst_n_payments) AS total_payments,
    SUM(inst_n_missed)   AS total_missed
FROM features.installments_by_applicant;

-- 3. Check ranges of the lateness features
-- Expect: min_share 0.0000 or above, max_share 1.0000 or below, share_out_of_range 0, max_below_avg 0
-- A share above 1 would mean integer division or a wrong denominator
-- NULL shares are skipped by both tests; they belong to applicants with no paid rows
SELECT
    MIN(inst_share_late)                                         AS min_share,
    MAX(inst_share_late)                                         AS max_share,
    COUNT(*) FILTER (WHERE inst_share_late < 0
                        OR inst_share_late > 1)                  AS share_out_of_range,
    COUNT(*) FILTER (WHERE inst_max_days_late < inst_avg_days_late) AS max_below_avg
FROM features.installments_by_applicant;

-- 4. Check applicant 100002: feature row vs a recompute from the raw payments
-- Expect: the two rows show identical numbers in every column
-- The recompute uses CASE and SUM instead of FILTER and COUNT, so it is not a copy of the feature code
SELECT
    'feature' AS source,
    inst_n_payments, inst_n_prev_loans, inst_n_missed,
    inst_avg_days_late, inst_max_days_late, inst_share_late, inst_pay_ratio
FROM features.installments_by_applicant
WHERE sk_id_curr = 100002
UNION ALL
SELECT
    'recompute',
    COUNT(*),
    COUNT(DISTINCT sk_id_prev),
    SUM(CASE WHEN days_entry_payment IS NULL THEN 1 ELSE 0 END),
    ROUND(AVG(days_entry_payment - days_installment), 2),
    MAX(days_entry_payment - days_installment),
    ROUND(SUM(CASE WHEN days_entry_payment - days_installment > 0 THEN 1 ELSE 0 END)::NUMERIC
          / COUNT(days_entry_payment), 4),
    ROUND(SUM(amt_payment) / SUM(amt_installment), 4)
FROM raw.installments_payments
WHERE sk_id_curr = 100002;
