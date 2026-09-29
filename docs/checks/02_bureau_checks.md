# Check results: `raw.bureau`

**Checks file:** `sql/02_checks.sql` · **Table:** `raw.bureau` · **Recorded:** 28 September 2026

## Summary

The table loaded completely: 1,716,428 loans held at other lenders. Its grain is one row per outside loan, with several rows per applicant, so it must be summarised to one row per applicant before joining. Two findings shape `06_agg_bureau.sql`: 17 records were updated after the application date, and 14% of training applicants have no bureau record at all.

## Results

| # | Check | Result | Status |
|---|---|---|---|
| 1 | Row count | 1,716,428 | ✅ Matches CSV |
| 2 | `sk_id_bureau` unique | 1,716,428 distinct | ✅ One row per loan |
| 3 | Missing values | Only 7 columns: `amt_annuity` 1,226,791 · `amt_credit_max_overdue` 1,124,488 · `days_enddate_fact` 633,653 · `amt_credit_sum_limit` 591,780 · `amt_credit_sum_debt` 257,669 · `days_credit_enddate` 105,553 · `amt_credit_sum` 13 | ℹ️ Noted |
| 4 | Missing end date by status | Active 628,638 of 630,607 · Sold 4,879 · Closed 125 · Bad debt 11 | ✅ Missing = loan not ended yet |
| 5 | Categories | Status: Closed 1,079,273 · Active 630,607 · Sold 6,527 · Bad debt 21. Currency 1 = 99.9%. 15 credit types, led by Consumer credit (1,251,615) and Credit card (402,195) | ℹ️ Noted |
| 6 | Whole-number checks | All 6 day and count columns: 0 non-whole | ✅ Safe to cast to INTEGER |
| 7 | Timeline | `days_credit` −2,922 to 0 · `days_enddate_fact` ≤ 0 · `days_credit_enddate` up to +31,199 · **`days_credit_update` > 0 for 17 rows (max +372)** | ⚠️ 17 future-dated rows |
| 8 | Loans per applicant | 305,811 applicants · 1 to 116 loans · average 5.61 | ⚠️ Must aggregate before joining |
| 9 | Coverage of training applicants | 263,491 of 307,511 (86%) have a bureau record | ℹ️ 44,020 have none |

## What the findings mean

- **Future planned end dates are fine.** A positive `days_credit_enddate` is a contract term the lender knew on application day.
- **Future updates are not.** A positive `days_credit_update` is information recorded after the decision. Using it would be leakage.
- **Missing bureau history is informative.** Applicants with no record default at 10.12%, against 7.73% for those with one.

## Decisions carried into `06_agg_bureau.sql`

| Finding | Decision |
|---|---|
| 17 future-dated updates (check 7) | Exclude with `WHERE days_credit_update <= 0`. This removes one applicant entirely (243211), leaving 305,810 |
| Several rows per applicant (check 8) | `GROUP BY sk_id_curr` to one row per applicant before joining |
| Day and count columns whole (check 6) | Cast to INTEGER in the aggregation's first stage |
| No bureau record for 14% (check 9) | In `07`, add a `has_bureau_history` flag, and fill counts with 0 but leave amounts NULL |
