# Decisions

## 05: installment features (`features.installments_by_applicant`)
- 7 features per applicant: `inst_n_payments`, `inst_n_prev_loans`, `inst_n_missed`, `inst_avg_days_late`, `inst_max_days_late`, `inst_share_late`, `inst_pay_ratio`. Each summarises repayment behaviour differently (volume, breadth, non-payment, typical lateness, worst lateness, consistency, underpayment).
- NULLs are kept, not filled with 0. An applicant with no paid rows has no lateness at all, and 0 would claim "perfectly on time". Missing history is itself a signal, and LightGBM handles NULL natively. Imputation for logistic regression happens inside the CV `Pipeline`.
- `sk_id_curr` and `sk_id_prev` are cast to INTEGER in the `cleaned` CTE (raw has NUMERIC), so file 07 joins like for like with `clean.application_train`.
- `::NUMERIC` on the share numerator avoids integer division (3/10 would give 0).
- `NULLIF(..., 0)` on both denominators turns divide-by-zero into NULL (9 applicants never paid; 290 rows have `amt_installment = 0`).
- Known limit: this counts payments, not installments; a two-level aggregation is a stretch improvement.
