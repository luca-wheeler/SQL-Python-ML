# Decisions

## 05: installment features (`features.installments_by_applicant`)
- 7 features per applicant: `inst_n_payments`, `inst_n_prev_loans`, `inst_n_missed`, `inst_avg_days_late`, `inst_max_days_late`, `inst_share_late`, `inst_pay_ratio`. Each summarises repayment behaviour differently (volume, breadth, non-payment, typical lateness, worst lateness, consistency, underpayment).
- NULLs are kept, not filled with 0. An applicant with no paid rows has no lateness at all, and 0 would claim "perfectly on time". Missing history is itself a signal, and LightGBM handles NULL natively. Imputation for logistic regression happens inside the CV `Pipeline`.
- `sk_id_curr` and `sk_id_prev` are cast to INTEGER in the `cleaned` CTE (raw has NUMERIC), so file 07 joins like for like with `clean.application_train`.
- `::NUMERIC` on the share numerator avoids integer division (3/10 would give 0).
- `NULLIF(..., 0)` on both denominators turns divide-by-zero into NULL (9 applicants never paid; 290 rows have `amt_installment = 0`).
- Known limit: this counts payments, not installments; a two-level aggregation is a stretch improvement.

## 06: bureau features (`raw.bureau`)
- 11.7% of active bureau loans have unknown debt (73,547 of 630,590 have `amt_credit_sum_debt` NULL).
- The debt ratio uses only loans where both debt and credit are known (otherwise the denominator includes loans the numerator skips, biasing the ratio down). The same `FILTER` condition is used in both sums.
- The unknown count is kept as its own feature (`bur_n_debt_unknown`), so a model can tell a ratio over one loan from one over many.
- `NULLIF(..., 0)` on the denominator: 4,157 applicants have known active credit summing to 0. Their ratio is NULL (undefined), not 0.
- `bur_debt_ratio` is NULL for 70,109 applicants: 54,001 have no active loans, 16,108 have active loans but all debts unknown or zero known credit. NULLs are kept, as in 05.
- `bur_active_debt` and `bur_active_credit` use only the `Active` filter, so they cover different loans than the ratio. Example: applicant 100016 has 63,724.5 / 336,757.5 = 0.19 from those two columns, but a ratio of 0.4072, because 2 of 4 active loans have unknown debt.
- Ratio tails: -309 to 382, but the median is 0.67 and the 99th percentile 1.08. 6,993 are above 1, 815 are negative (8,418 raw loans have negative debt, probably credit balances). Left as is in SQL; clipping for logistic regression goes in the CV `Pipeline` so percentiles come from training folds only.
- `WHERE days_credit_update <= 0` drops 17 raw rows (1 applicant, who has no features) and is almost a no-op. Kept as a guard against updates dated after the application.
- 8 active loans have NULL `amt_credit_sum`, so they sit in the ratio numerator but not the denominator. Too small to matter; add `AND amt_credit_sum IS NOT NULL` to the filters if it ever does.
- Past mistake worth remembering: the denominator once summed the debt column, giving a ratio of exactly 1.0000 for everyone. Check 3b catches it (min and max must differ).
