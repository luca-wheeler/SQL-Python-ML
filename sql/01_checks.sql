-- 01_checks.sql
-- Data quality checks for installments_payments after loading (01_load_installments.sql).
-- Run: docker compose exec -T db psql -U luca -d credit_risk < sql/01_checks.sql

-- 1. Row count
-- Expected: 13,605,401 (wc -l on the CSV minus 1 header line)
SELECT COUNT(*) AS total_rows
FROM installments_payments;

-- 2. NULL count per column
-- Found: only days_entry_payment and amt_payment have NULLs (2,905 each)
SELECT
    COUNT(*)                                  AS total_rows,
    COUNT(*) - COUNT(sk_id_prev)              AS sk_id_prev_nulls,
    COUNT(*) - COUNT(sk_id_curr)              AS sk_id_curr_nulls,
    COUNT(*) - COUNT(num_installment_version) AS num_installment_version_nulls,
    COUNT(*) - COUNT(num_installment_number)  AS num_installment_number_nulls,
    COUNT(*) - COUNT(days_installment)        AS days_installment_nulls,
    COUNT(*) - COUNT(days_entry_payment)      AS days_entry_payment_nulls,
    COUNT(*) - COUNT(amt_installment)         AS amt_installment_nulls,
    COUNT(*) - COUNT(amt_payment)             AS amt_payment_nulls
FROM installments_payments;

-- 3. Are the NULLs in the same rows? (instalments due but never paid)
-- Expect: 2,905
-- Found: the NULLs are the same rows
SELECT COUNT(*) AS missing_payment_rows
FROM installments_payments
WHERE days_entry_payment IS NULL
  AND amt_payment IS NULL;

-- 4. Whole-number checks: columns loaded as NUMERIC because the CSV writes
-- Expected: 0 for each, meaning it's safe to cast to INTEGER during cleaning.
-- NULLs are skipped (NULL <> x is NULL, not true).
SELECT COUNT(*) AS days_installment_non_whole
FROM installments_payments
WHERE days_installment <> TRUNC(days_installment);

SELECT COUNT(*) AS days_entry_payment_non_whole
FROM installments_payments
WHERE days_entry_payment <> TRUNC(days_entry_payment);

SELECT COUNT(*) AS num_installment_version_non_whole
FROM installments_payments
WHERE num_installment_version <> TRUNC(num_installment_version);