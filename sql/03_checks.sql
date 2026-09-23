-- 03_checks.sql
-- Data quality checks for raw.application_train after loading (03_load_application.sql).
-- Run: docker compose exec -T db psql -U luca -d credit_risk < sql/03_checks.sql
-- Every "Expected" value below was computed directly from application_train.csv.

-- 1. Row count
-- Expected: 307,511
SELECT COUNT(*) AS total_rows
FROM raw.application_train;

-- 2. Is sk_id_curr a unique key? (one row per applicant)
-- Expected: distinct_applicants = total_rows = 307,511
SELECT
    COUNT(*)                    AS total_rows,
    COUNT(DISTINCT sk_id_curr)  AS distinct_applicants
FROM raw.application_train;

-- 3. The label: class balance
-- Expected: 0 -> 282,686 (91.93%) | 1 -> 24,825 (8.07%)
-- Only about 1 in 12 applicants had difficulties, so a model that always
-- predicts 0 scores 92% accuracy and is useless. That's why we use Gini/AUC.
SELECT
    target,
    COUNT(*)                                            AS applicants,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)  AS pct
FROM raw.application_train
GROUP BY target
ORDER BY target;

-- 4. NULL counts for the key columns
-- Expected:
--   ext_source_1 173,378 (56%) | ext_source_2 660 | ext_source_3 60,965 (20%)
--   amt_annuity 12 | amt_goods_price 278 | cnt_fam_members 2
--   occupation_type 96,391 (31%) | own_car_age 202,929 (66%)
SELECT
    COUNT(*)                            AS total_rows,
    COUNT(*) - COUNT(target)            AS target_nulls,
    COUNT(*) - COUNT(amt_income_total)  AS amt_income_total_nulls,
    COUNT(*) - COUNT(amt_credit)        AS amt_credit_nulls,
    COUNT(*) - COUNT(amt_annuity)       AS amt_annuity_nulls,
    COUNT(*) - COUNT(amt_goods_price)   AS amt_goods_price_nulls,
    COUNT(*) - COUNT(days_birth)        AS days_birth_nulls,
    COUNT(*) - COUNT(days_employed)     AS days_employed_nulls,
    COUNT(*) - COUNT(cnt_fam_members)   AS cnt_fam_members_nulls,
    COUNT(*) - COUNT(occupation_type)   AS occupation_type_nulls,
    COUNT(*) - COUNT(own_car_age)       AS own_car_age_nulls,
    COUNT(*) - COUNT(ext_source_1)      AS ext_source_1_nulls,
    COUNT(*) - COUNT(ext_source_2)      AS ext_source_2_nulls,
    COUNT(*) - COUNT(ext_source_3)      AS ext_source_3_nulls
FROM raw.application_train;

-- 5. NULL counts for ALL 122 columns at once, most-missing first.
-- Expected: 67 columns have NULLs; the worst are the commonarea_* building
-- columns with 214,865 each (70%).
-- How it works:
--   to_jsonb(t)      turns each row into a JSON object {"column": value, ...}
--   jsonb_each(...)  splits that object into one (key, value) row per column
--   a SQL NULL becomes the JSON value 'null', so we count those per column.
-- It builds 307,511 x 122 = 37.5M intermediate rows, so give it ~30 seconds.
SELECT
    key                                                  AS column_name,
    COUNT(*) FILTER (WHERE value = 'null'::jsonb)        AS nulls,
    ROUND(100.0 * COUNT(*) FILTER (WHERE value = 'null'::jsonb) / COUNT(*), 1)
                                                         AS pct_null
FROM raw.application_train AS t,
     jsonb_each(to_jsonb(t))
GROUP BY key
HAVING COUNT(*) FILTER (WHERE value = 'null'::jsonb) > 0
ORDER BY nulls DESC;

-- 6. The DAYS_EMPLOYED placeholder (365243 days = about 1,000 years in the FUTURE)
-- Expected: 55,374 rows; income types Pensioner 55,352 and Unemployed 22.
-- So 365243 means "not employed", not a real number of days. Every other
-- days_employed value is <= 0, as it should be.
SELECT
    name_income_type,
    COUNT(*) AS applicants
FROM raw.application_train
WHERE days_employed = 365243
GROUP BY name_income_type
ORDER BY applicants DESC;

-- Expected: 0 (no other positive, i.e. future, employment start dates)
SELECT COUNT(*) AS other_positive_days_employed
FROM raw.application_train
WHERE days_employed > 0
  AND days_employed <> 365243;

-- 7. 'XNA' = "not available" written as text rather than as a real NULL.
--    COUNT(column) does NOT catch these, so they hide from the NULL checks.
-- Expected: code_gender 4 | organization_type 55,374 | name_family_status 2 ('Unknown')
-- Note organization_type XNA = 55,374 = exactly the DAYS_EMPLOYED placeholder
-- rows: both say "this person has no employer".
SELECT
    COUNT(*) FILTER (WHERE code_gender = 'XNA')             AS code_gender_xna,
    COUNT(*) FILTER (WHERE organization_type = 'XNA')       AS organization_type_xna,
    COUNT(*) FILTER (WHERE name_family_status = 'Unknown')  AS family_status_unknown
FROM raw.application_train;

-- 8. Whole-number checks for count and days columns loaded as NUMERIC.
-- Expected: 0 everywhere EXCEPT days_registration = 1.
-- That one row (sk_id_curr 408583, value -10116.0416...) is a data error:
-- round it (or set to NULL) during cleaning before casting to INTEGER.
SELECT
    COUNT(*) FILTER (WHERE cnt_children           <> TRUNC(cnt_children))           AS cnt_children_non_whole,
    COUNT(*) FILTER (WHERE cnt_fam_members        <> TRUNC(cnt_fam_members))        AS cnt_fam_members_non_whole,
    COUNT(*) FILTER (WHERE days_birth             <> TRUNC(days_birth))             AS days_birth_non_whole,
    COUNT(*) FILTER (WHERE days_employed          <> TRUNC(days_employed))          AS days_employed_non_whole,
    COUNT(*) FILTER (WHERE days_registration      <> TRUNC(days_registration))      AS days_registration_non_whole,
    COUNT(*) FILTER (WHERE days_id_publish        <> TRUNC(days_id_publish))        AS days_id_publish_non_whole,
    COUNT(*) FILTER (WHERE days_last_phone_change <> TRUNC(days_last_phone_change)) AS days_last_phone_change_non_whole
FROM raw.application_train;

-- Show the offending row
-- Expected: sk_id_curr 408583, days_registration -10116.041666666662
SELECT sk_id_curr, days_registration
FROM raw.application_train
WHERE days_registration <> TRUNC(days_registration);

-- 9. Range sanity checks
-- Expected:
--   days_birth between -25,229 and -7,489  -> ages about 20.5 to 69 years
--   cnt_children max 19 | cnt_fam_members max 20 (rare but possible)
--   ext_source_1/2/3 all between 0 and 1   (normalised scores)
--   amt_income_total max 117,000,000       -> extreme outlier (next highest is
--       18,000,090), and that applicant has target = 1. Decide in cleaning
--       whether to cap it; it will distort averages and linear models.
--   amt_credit: 0 rows <= 0
SELECT
    MIN(days_birth)                                  AS days_birth_min,
    MAX(days_birth)                                  AS days_birth_max,
    ROUND(-MIN(days_birth) / 365.25, 1)              AS oldest_age_years,
    ROUND(-MAX(days_birth) / 365.25, 1)              AS youngest_age_years,
    MAX(cnt_children)                                AS cnt_children_max,
    MAX(cnt_fam_members)                             AS cnt_fam_members_max,
    MIN(LEAST(ext_source_1, ext_source_2, ext_source_3))    AS ext_source_min,
    MAX(GREATEST(ext_source_1, ext_source_2, ext_source_3)) AS ext_source_max,
    MAX(amt_income_total)                            AS amt_income_total_max,
    COUNT(*) FILTER (WHERE amt_credit <= 0)          AS non_positive_credit
FROM raw.application_train;

-- Top 3 incomes: is the maximum a one-off?
-- Expected: 117,000,000 (target 1) | 18,000,090 | 13,500,000
SELECT sk_id_curr, amt_income_total, target
FROM raw.application_train
ORDER BY amt_income_total DESC
LIMIT 3;

-- 10. Flag columns should only ever be 0 or 1.
-- Expected: 0 for every column checked (all 26 numeric flag_ columns pass;
-- a representative set is checked here).
SELECT
    COUNT(*) FILTER (WHERE flag_mobil       NOT IN (0, 1)) AS flag_mobil_bad,
    COUNT(*) FILTER (WHERE flag_emp_phone   NOT IN (0, 1)) AS flag_emp_phone_bad,
    COUNT(*) FILTER (WHERE flag_email       NOT IN (0, 1)) AS flag_email_bad,
    COUNT(*) FILTER (WHERE flag_document_2  NOT IN (0, 1)) AS flag_document_2_bad,
    COUNT(*) FILTER (WHERE flag_document_3  NOT IN (0, 1)) AS flag_document_3_bad,
    COUNT(*) FILTER (WHERE flag_document_21 NOT IN (0, 1)) AS flag_document_21_bad
FROM raw.application_train;

-- The two text flags use Y/N instead of 1/0.
-- Expected: flag_own_car N 202,924 / Y 104,587 | flag_own_realty Y 213,312 / N 94,199
SELECT 'flag_own_car' AS flag, flag_own_car AS value, COUNT(*) AS applicants
FROM raw.application_train GROUP BY flag_own_car
UNION ALL
SELECT 'flag_own_realty', flag_own_realty, COUNT(*)
FROM raw.application_train GROUP BY flag_own_realty
ORDER BY flag, value;
