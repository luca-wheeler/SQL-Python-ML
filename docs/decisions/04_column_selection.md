# Decision record: column selection for `clean.application_train`

| | |
|---|---|
| **File** | `sql/04_clean_application.sql` |
| **Status** | Accepted |
| **Date** | 28 September 2026 |
| **Author** | Luca Wheeler |

## Summary

`raw.application_train` has 122 columns. The cleaned table keeps **36 of them** and produces **37 output columns**. Three are derived: `is_not_employed` and `years_employed` from `days_employed`, and `age_years` from `days_birth`. The other **86 raw columns are rejected**.

The aim is a feature set that is small enough to explain line by line and keeps the strongest signal. Rejected columns can be added back later if they improve cross-validated Gini.

## Selection criteria

A column is kept if it meets all of these:

1. **Known at application time.** No information from after the decision.
2. **Carries signal.** Measured as a single-column Gini against `target` (method below).
3. **Mostly present.** Or, if heavily missing, strong enough to justify it (e.g. `ext_source_1`).
4. **Not redundant.** It adds something that no kept column already captures.
5. **Explainable.** Its meaning is clear from the data dictionary.

For scale, the strongest kept columns score: `ext_source_3` 0.359, `ext_source_1` 0.331, `ext_source_2` 0.312.

## Columns kept (37 output columns)

| Topic | Output columns | Treatment | Reason |
|---|---|---|---|
| Keys and label | `sk_id_curr`, `target` | Unchanged | Join key and model label |
| Loan | `name_contract_type`, `amt_credit`, `amt_annuity`, `amt_goods_price` | Unchanged | Core loan terms; used for ratio features in `07` |
| Work and income | `amt_income_total`, `name_income_type`, `occupation_type` | Unchanged | Affordability and job type |
| | `organization_type` | `'XNA'` → NULL | `'XNA'` marks the 55,374 applicants with no employer |
| | `is_not_employed` *(new)* | 1 if `days_employed = 365243` | Keeps the placeholder's meaning: this group defaults at 5.40% vs 8.66% |
| | `years_employed` *(new)* | 365243 → NULL, then −days ÷ 365.25 | Removes a fake 1,000-year value; readable units |
| Person and household | `age_years` *(new)* | −`days_birth` ÷ 365.25 | Readable units; unrounded to keep full precision |
| | `cnt_children`, `cnt_fam_members` | → INTEGER | Household size |
| | `name_family_status` | `'Unknown'` → NULL | 2 placeholder rows |
| | `code_gender` | `'XNA'` → NULL | 4 placeholder rows; model use to be decided (see *Open questions*) |
| | `name_education_type`, `name_housing_type` | Unchanged | Stability indicators |
| Assets | `flag_own_car`, `flag_own_realty` | Y/N → 1/0 | Consistent with other flags |
| | `own_car_age` | → INTEGER | 66% missing, but missing means "no car", which is informative |
| Region | `region_population_relative` | Unchanged | Urban vs rural |
| | `region_rating_client_w_city` | → INTEGER | Home Credit's region risk rating (Gini 0.098) |
| External credit scores | `ext_source_1`, `ext_source_2`, `ext_source_3` | Unchanged | Strongest predictors in the dataset |
| Dates | `days_registration` | ROUND → INTEGER | One value off by exactly one hour (applicant 408583); rounding recovers it |
| | `days_id_publish`, `days_last_phone_change` | → INTEGER | Recent changes to ID or phone are a known risk signal |
| Social circle | `def_30_cnt_social_circle`, `def_60_cnt_social_circle` | → INTEGER | Defaults among the applicant's contacts |
| Documents and contact | `flag_document_3` | → INTEGER | The only common document flag (71% provide it) |
| | `flag_work_phone` | → INTEGER | Contact stability |
| Credit bureau enquiries | `amt_req_credit_bureau_qrt`, `amt_req_credit_bureau_year` | → INTEGER | Recent credit-seeking behaviour |
| Building | `totalarea_mode` | Unchanged | One summary stands in for 47 building columns |

## Columns rejected (86 raw columns)

| Group | Count | Columns | Evidence | Reason |
|---|---|---|---|---|
| Building statistics | 46 | `*_avg`, `*_mode`, `*_medi` (e.g. `floorsmax_avg`, `livingarea_mode`), plus `fondkapremont_mode`, `housetype_mode`, `wallsmaterial_mode`, `emergencystate_mode` | 47–70% missing; best Gini 0.101 | Three near-copies of each measurement; heavily missing; `totalarea_mode` kept as the summary |
| Document flags | 19 | `flag_document_2`, `_4` to `_21` | Best Gini 0.030; 17 of 19 provided by under 2% of applicants | Too rare to learn from |
| Contact flags | 5 | `flag_mobil`, `flag_cont_mobile`, `flag_phone`, `flag_email`, `flag_emp_phone` | `flag_mobil` is 1 for effectively 100%; `flag_cont_mobile` 99.8% | Near-constant. `flag_emp_phone = 0` matches the not-employed group almost exactly (55,374 of 55,386), duplicating `is_not_employed` |
| Region/city mismatch flags | 6 | `reg_region_not_live_region`, `reg_region_not_work_region`, `live_region_not_work_region`, `reg_city_not_live_city`, `reg_city_not_work_city`, `live_city_not_work_city` | Gini 0.002–0.079 | Weak; `reg_city_not_work_city` is the strongest (see *Open questions*) |
| Duplicate region rating | 1 | `region_rating_client` | Correlation 0.951 with the kept `_w_city` version | Redundant |
| Social circle observations | 2 | `obs_30_cnt_social_circle`, `obs_60_cnt_social_circle` | Best Gini 0.018; the two are 0.9985 correlated | Weak; the default counts (`def_*`) are kept instead |
| Short-window enquiries | 4 | `amt_req_credit_bureau_hour`, `_day`, `_week`, `_mon` | Best Gini 0.010; hour and day are non-zero for 0.6% of applicants | Sparse; quarter and year windows kept |
| Application timing | 2 | `weekday_appr_process_start`, `hour_appr_process_start` | Best Gini 0.048 | Describe when the form was processed, not the borrower |
| Accompanying person | 1 | `name_type_suite` | Gini 0.015 | Weak and hard to justify as a credit factor |

## Method: single-column Gini

Each column was scored on its own against `target`: Gini = 2 × |AUC − 0.5|, on rows where the column is present. Text columns were scored by their category default rates, which slightly flatters them. The score ignores overlap between columns, so it screens for obvious signal and doesn't measure a column's final value in the model. LightGBM feature importance will be the real test.

## Open questions (revisit after the first model)

- **`reg_city_not_work_city`**: the strongest rejected column that isn't a building column (Gini 0.079, no missing values). It's the first candidate to add back.
- **`floorsmax_avg`**: scores slightly higher than `totalarea_mode` (0.101 vs 0.091). Consider swapping the building summary.
- **`code_gender` and age**: kept for analysis. Whether the model uses them is a fairness decision, because UK equality law restricts using protected characteristics in credit decisions. Compare model quality with and without them.
- **Income outlier**: one applicant reports 117,000,000 (next highest 18,000,090). Handled in Python, with a log transform for logistic regression, rather than capped in SQL.
