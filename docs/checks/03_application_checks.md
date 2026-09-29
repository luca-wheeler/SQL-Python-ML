# Check results: `raw.application_train`

**Checks file:** `sql/03_checks.sql` · **Table:** `raw.application_train` · **Recorded:** 28 September 2026

## Summary

The table loaded completely: 307,511 rows, one per applicant. The data is sound, but it has four problems to fix in cleaning: an employment placeholder, text placeholders (`'XNA'`, `'Unknown'`), one non-whole day value, and heavily missing building columns. Each finding below links to the decision it led to in `04_clean_application.sql`.

## Results

| # | Check | Result | Status |
|---|---|---|---|
| 1 | Row count | 307,511 | ✅ Matches CSV |
| 2 | `sk_id_curr` unique | 307,511 distinct of 307,511 | ✅ One row per applicant |
| 3 | Class balance (`target`) | 0: 282,686 (91.93%) · 1: 24,825 (8.07%) | ℹ️ Imbalanced |
| 4 | Missing values, key columns | `ext_source_1` 173,378 (56%) · `ext_source_3` 60,965 (20%) · `ext_source_2` 660 · `occupation_type` 96,391 (31%) · `own_car_age` 202,929 (66%) · `amt_goods_price` 278 · `amt_annuity` 12 · `cnt_fam_members` 2 | ℹ️ Noted |
| 5 | Missing values, all columns | 67 of 122 columns have NULLs; worst: `commonarea_*` 214,865 (69.9%) | ⚠️ Building columns heavily missing |
| 6 | `days_employed = 365243` | 55,374 rows: Pensioner 55,352, Unemployed 22. No other positive values | ⚠️ Placeholder |
| 7 | Text placeholders | `organization_type = 'XNA'` 55,374 · `code_gender = 'XNA'` 4 · `name_family_status = 'Unknown'` 2 | ⚠️ Placeholder |
| 8 | Whole-number checks | All 0 except `days_registration`: 1 row (applicant 408583, −10116.041666666662) | ⚠️ One bad value |
| 9 | Ranges | Age 20.5–69.1 years · `cnt_children` ≤ 19 · `cnt_fam_members` ≤ 20 · `ext_source_*` within 0–1 · `amt_credit` never ≤ 0 · `amt_income_total` max 117,000,000 (next 18,000,090) | ⚠️ One income outlier |
| 10 | Flag values | All 26 numeric `flag_*` columns are 0/1 · `flag_own_car` N 202,924 / Y 104,587 · `flag_own_realty` Y 213,312 / N 94,199 | ✅ Y/N text needs converting |

## Follow-up investigation

| Question | Finding |
|---|---|
| Are the `'XNA'` organisation rows the same as the 365243 rows? | Yes, exactly. Cross-tabulating gives 55,374 rows with both and 0 with only one. Both mean "no employer". |
| Why does one `days_registration` have decimals? | The fraction is exactly 1/24 of a day (one hour). The applicant's registration date equals their birth date, which is true for 906 applicants; this one is off by an hour, most likely a date-time artefact. |
| Does the not-employed group behave differently? | Yes: it defaults at 5.40% vs 8.66% for everyone else. |
| Any other suspicious values? | `days_last_phone_change` is 0 for 37,672 applicants (12%). This could be a real same-day change or a default value; it can't be told apart from the data alone. |

## Decisions carried into `04_clean_application.sql`

| Finding | Decision |
|---|---|
| 365243 placeholder (check 6) | Convert to NULL in `years_employed`, and keep the information as a flag, `is_not_employed` |
| `'XNA'` / `'Unknown'` (check 7) | `NULLIF` to a real NULL in `organization_type`, `code_gender`, `name_family_status` |
| Non-whole `days_registration` (check 8) | `ROUND` then cast to INTEGER; this recovers the intended value exactly |
| All other day and count columns whole (check 8) | Cast to INTEGER safely |
| Y/N flags (check 10) | Convert to 1/0 |
| Negative day counts | Convert age and employment to positive years, unrounded |
| Building columns 47–70% missing (check 5) | Keep one summary, `totalarea_mode`; reject the other 46 |
| Income outlier (check 9) | Leave in SQL; handle in the Python pipeline |
| Class imbalance (check 3) | Use Gini/AUC, not accuracy, with stratified cross-validation |

Full column reasoning: [`docs/decisions/04_column_selection.md`](../decisions/04_column_selection.md).
