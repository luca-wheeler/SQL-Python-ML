# Check results: `clean.application_train`

**Checks file:** `sql/04_checks.sql` · **Table:** `clean.application_train` · **Recorded:** 29 September 2026

## Summary

The clean table is correct. It holds the same 307,511 applicants as the raw table, one row each, with 37 columns. All eleven checks matched their expected values: placeholders became NULL, flags became 1/0, day counts became years, the types are what was intended, and genuine missing values were carried over unchanged. Nothing needs fixing before the aggregation files (05 and 06).

## Results

| # | Check | Result | Status |
|---|---|---|---|
| 1 | Row count and unique key | 307,511 rows, 307,511 distinct `sk_id_curr` | ✅ One row per applicant |
| 2 | Column count | 37 | ✅ Matches |
| 3 | Employment placeholder | `years_employed` NULLs 55,374 = `is_not_employed` total 55,374 · min 0.00 · max 49.04 · avg 6.53 | ✅ Placeholder gone and flagged |
| 4 | `'XNA'` / `'Unknown'` to NULL | `organization_type` 55,374 · `code_gender` 4 · `name_family_status` 2 | ✅ Match the raw placeholder counts |
| 5 | Ages | Youngest 20.50 · oldest 69.07 · average 43.91 | ✅ All positive, plausible |
| 6 | Y/N flags to 1/0 | `flag_own_car` sum 104,587 · `flag_own_realty` sum 213,312 · `flag_own_car` NULLs 0 | ✅ Match the raw `'Y'` counts |
| 7 | Every 0/1 column holds only 0 or 1 | `is_not_employed`, `flag_own_car`, `flag_own_realty`, `flag_document_3`, `flag_work_phone`: 0 bad values each (NULL counts as bad) | ✅ All clean |
| 8 | Rounded `days_registration` | Applicant 408583 is `-10116` (raw was −10116.041666666662) | ✅ Rounded |
| 9 | Column types | `age_years` numeric · `amt_credit` numeric · `cnt_children` integer · `code_gender` text · `days_registration` integer · `flag_own_car` integer | ✅ As intended |
| 10 | Default rate by `is_not_employed` | 0: 252,137 applicants, 8.66% · 1: 55,374 applicants, 5.40% | ✅ Same as raw-table finding |
| 11 | Real NULLs carried over | `cnt_fam_members` 2 · `own_car_age` 202,929 · `amt_req_credit_bureau_year` 41,519 · `totalarea_mode` 148,431 · `ext_source_1` 173,378 | ✅ Unchanged |

## What each group of checks proves

| Checks | Question answered |
|---|---|
| 1–2 | Is the shape right? Cleaning must not add or drop applicants or columns. |
| 3–8 | Did each fix work? Each links back to a decision in `03_application_checks.md`. |
| 9 | Are the types as intended? `CREATE TABLE AS SELECT` infers them from the expressions, so this is worth checking. |
| 10–11 | Did cleaning keep what matters? The not-employed signal survives as a flag, and real NULLs are neither lost nor invented. |

## How the checks tie back to the raw-table findings

| Raw finding (`03_application_checks.md`) | Verified by |
|---|---|
| 365243 placeholder, 55,374 rows (check 6) | Checks 3 and 10 |
| `'XNA'` / `'Unknown'` placeholders (check 7) | Check 4 |
| One non-whole `days_registration` (check 8) | Checks 8 and 9 |
| Y/N flag counts (check 10) | Checks 6 and 7 |
| Age range 20.5–69.1 (check 9) | Check 5 |
| Not-employed group defaults 5.40% vs 8.66% | Check 10 |
| Key column NULL counts (check 4) | Check 11 |

## Notes

- Check 3: `min_years` and `max_years` print with many decimals in `psql` (0.0000… and 49.0403832991…) because `years_employed` is unrounded NUMERIC. The table above rounds them to 2 places.
- Check 7: each count is `NOT IN (0, 1) OR IS NULL`. `NOT IN` alone ignores NULLs, because `NULL NOT IN (0, 1)` is NULL rather than true, so the `IS NULL` part is what makes NULLs count as bad.
- Check 11 only covers columns that were copied or cast. Columns changed on purpose (checks 3 and 4) are expected to differ from the raw NULL counts.

Full column reasoning: [`docs/decisions/04_column_selection.md`](../decisions/04_column_selection.md).
