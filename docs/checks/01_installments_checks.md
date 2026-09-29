# Check results: `raw.installments_payments`

**Checks file:** `sql/01_checks.sql` · **Table:** `raw.installments_payments` · **Recorded:** 28 September 2026

## Summary

The table loaded completely: 13,605,401 payments on previous Home Credit loans. Its grain is one row per payment, with many rows per applicant. The only missing values are 2,905 payments that were due but never made, which is itself a strong risk signal.

## Results

| # | Check | Result | Status |
|---|---|---|---|
| 1 | Row count | 13,605,401 | ✅ Matches CSV |
| 2 | Missing values | Only `days_entry_payment` (2,905) and `amt_payment` (2,905); all other columns complete | ℹ️ Noted |
| 3 | Are both NULLs in the same rows? | _Run check 3 and record the count here. Expected 2,905._ | ⏳ To record |
| 4a | `days_installment` whole numbers | 0 non-whole | ✅ Safe to cast |
| 4b | `days_entry_payment` whole numbers | _Run and record. Expected 0._ | ⏳ To record |
| 4c | `num_installment_version` whole numbers | _Run and record. Expected 0._ | ⏳ To record |

## What the findings mean

- **The 2,905 missing rows are unpaid installments, not bad data.** If check 3 confirms they're the same rows, each one is an installment that was due and never paid.
- **Averages would silently hide them.** `AVG` skips NULLs, so these rows need to be counted separately.

## Decisions carried into `05_agg_installments.sql`

| Finding | Decision |
|---|---|
| Unpaid installments (check 2) | Count them per applicant as `inst_n_missed` |
| Lateness only exists for paid rows | `inst_avg_days_late` averages paid rows only |
| Day columns whole (check 4) | Cast to INTEGER in the aggregation's first stage |
| Many rows per applicant | `GROUP BY sk_id_curr` to one row per applicant |
