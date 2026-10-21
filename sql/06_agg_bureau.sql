-- 06_agg_bureau.sql
-- Build features.bureau_by_applicant.
-- Grain in: one row per loan at another lender (1,716,428 rows).
-- Grain out: one row per applicant

\timing on

CREATE SCHEMA IF NOT EXISTS features;

DROP TABLE IF EXISTS features.bureau_by_applicant;

CREATE TABLE features.bureau_by_applicant AS
WITH cleaned AS (
    SELECT
        sk_id_curr::INTEGER             AS sk_id_curr,
        credit_active                   AS credit_active,
        days_credit::INTEGER            AS days_credit,
        credit_day_overdue::INTEGER     AS credit_day_overdue,
        amt_credit_sum                  AS amt_credit_sum,
        amt_credit_sum_debt             AS amt_credit_sum_debt,
        amt_credit_sum_overdue          AS amt_credit_sum_overdue,
        days_credit_update              AS days_credit_update
    FROM raw.bureau
    WHERE days_credit_update <= 0
        
)
SELECT
    sk_id_curr,
    COUNT(*)                                                            AS bur_n_loans,
    COUNT(*) FILTER (WHERE credit_active = 'Active')                    AS bur_n_active,
    COUNT(*) FILTER (WHERE credit_active IN ('Bad debt', 'Sold'))       AS bur_n_bad,
    COUNT(*) FILTER (
        WHERE credit_active = 'Active'
        AND amt_credit_sum_debt IS NULL
    )                                                                   AS bur_n_debt_unknown,
    SUM(amt_credit_sum_debt) FILTER (WHERE credit_active = 'Active')    AS bur_active_debt,
    SUM(amt_credit_sum) FILTER (WHERE credit_active = 'Active')    AS bur_active_credit,
    ROUND(
        SUM(amt_credit_sum_debt) FILTER (
            WHERE credit_active = 'Active'
            AND amt_credit_sum IS NOT NULL
            AND amt_credit_sum_debt IS NOT NULL
        )
        /
        NULLIF(
            (SUM(amt_credit_sum) FILTER (
                WHERE credit_active = 'Active'
                AND amt_credit_sum IS NOT NULL
                AND amt_credit_sum_debt IS NOT NULL
            )),
            0
        ),
        4
                                                                           )                                                                   AS bur_debt_ratio,
    MAX(credit_day_overdue)                                             AS bur_max_days_overdue,
    SUM(amt_credit_sum_overdue)                                         AS bur_total_overdue,
    - MAX(days_credit)                                                  AS bur_days_since_last
FROM cleaned
GROUP BY sk_id_curr;