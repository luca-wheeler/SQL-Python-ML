-- 05_agg_installments.sql
-- Build features.installments_by_applicant from raw.installments_payments.
-- Grain in:  one row per payment (13,605,401 rows).
-- Grain out: one row per applicant.
-- days_late = days_entry_payment - days_installment
--   positive = paid late, negative = paid early, NULL = never paid.

\timing on

CREATE SCHEMA IF NOT EXISTS features;

DROP TABLE IF EXISTS features.installments_by_applicant;

CREATE TABLE features.installments_by_applicant AS
WITH cleaned AS (
    SELECT
        sk_id_curr::INTEGER                                   AS sk_id_curr,
        sk_id_prev::INTEGER                                   AS sk_id_prev,
        days_entry_payment::INTEGER                           AS days_paid,
        (days_entry_payment - days_installment)::INTEGER      AS days_late,
        amt_installment,
        amt_payment
    FROM raw.installments_payments
)
SELECT
    sk_id_curr,
    COUNT(*)                                     AS inst_n_payments,
    COUNT(DISTINCT sk_id_prev)                   AS inst_n_prev_loans,
    COUNT(*) FILTER (WHERE days_paid IS NULL)    AS inst_n_missed,
    ROUND(AVG(days_late), 2)                     AS inst_avg_days_late,
    MAX(days_late)                               AS inst_max_days_late,
    ROUND(
        COUNT(*) FILTER (WHERE days_late > 0)::NUMERIC
        / NULLIF(COUNT(days_paid), 0),
        4
    )                                            AS inst_share_late,
    ROUND(SUM(amt_payment) / NULLIF(SUM(amt_installment), 0), 4)
                                                 AS inst_pay_ratio
FROM cleaned
GROUP BY sk_id_curr;
