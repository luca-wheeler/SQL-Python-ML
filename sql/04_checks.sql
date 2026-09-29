-- 04_checks.sql
-- Tests that clean.application_train (built by 04_clean_application.sql) is right.
-- Run: docker compose exec -T db psql -U luca -d credit_risk < sql/04_checks.sql
-- Each check compares the clean table with what 03_checks.sql found in the raw table.
-- The checks fall into four groups:
--   1-2    shape: right number of rows and columns?
--   3-7    fixes: did each cleaning decision work?
--   8      types: is each column the type we intended?
--   9-10   safety: did cleaning keep the real signal and the real NULLs?

\timing on

-- 1. Check row count unchanged and that applicants are distinct
-- Expect: total_rows 307511, distinct_applicants 307511
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT sk_id_curr) AS distinct_applicants
FROM clean.application_train;

-- 2. Check number of columns
-- Expect: n_columns 37
SELECT COUNT(*) AS n_columns
FROM information_schema.columns
WHERE table_schema = 'clean' AND table_name = 'application_train';

-- 3. Check that placeholder 365243 is replaced by NULL, and flagged by is_not_employed
-- Expect: years_employed_nulls 55374, not_employed 55374 (must match), min_years 0.00, max_years 49.04, avg_years 6.53
-- A max_years near 1000 would mean the placeholder is still there
SELECT
    COUNT(*) FILTER (WHERE years_employed IS NULL) AS years_employed_nulls,
    SUM(is_not_employed)                           AS not_employed,
    MIN(years_employed)                            AS min_years,
    MAX(years_employed)                            AS max_years,
    ROUND(AVG(years_employed), 2)                  AS avg_years
FROM clean.application_train;

-- 4. Check that 'XNA' and 'Unknown' became NULL
-- Expect: organization_type_nulls 55374, code_gender_nulls 4, family_status_nulls 2
-- These should equal the placeholder counts found in 03_checks.sql
SELECT
    COUNT(*) - COUNT(organization_type)  AS organization_type_nulls,
    COUNT(*) - COUNT(code_gender)        AS code_gender_nulls,
    COUNT(*) - COUNT(name_family_status) AS family_status_nulls
FROM clean.application_train;

-- 5. Check that ages are positive and sensible
-- Expect: youngest 20.50, oldest 69.07, average_age 43.91
-- A negative age would mean the minus sign is missing
SELECT
    MIN(age_years)           AS youngest,
    MAX(age_years)           AS oldest,
    ROUND(AVG(age_years), 2) AS average_age
FROM clean.application_train;

-- 6. Check that Y/N flags are now 1/0
-- Expect: own_car 104587, own_realty 213312, car_nulls 0, car_bad 0
-- Summing a 0/1 column counts the 1s, so these match the 'Y' counts from 03_checks.sql
-- car_bad counts any value that is not 0 or 1
SELECT
    SUM(flag_own_car)                                  AS own_car,
    SUM(flag_own_realty)                               AS own_realty,
    COUNT(*) - COUNT(flag_own_car)                     AS car_nulls,
    COUNT(*) FILTER (WHERE flag_own_car NOT IN (0, 1)) AS car_bad
FROM clean.application_train;

-- 7. Check that the one decimal days_registration was rounded
-- Expect: sk_id_curr 408583, days_registration -10116
-- In the raw table this applicant had -10116.041666666662
SELECT sk_id_curr, days_registration
FROM clean.application_train
WHERE sk_id_curr = 408583;

-- 8. Check that column types are what we intended
-- Expect: age_years numeric, amt_credit numeric, cnt_children integer,
--         code_gender text, days_registration integer, flag_own_car integer
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'application_train'
  AND column_name IN ('cnt_children', 'days_registration', 'flag_own_car',
                      'age_years', 'amt_credit', 'code_gender')
ORDER BY column_name;

-- 9. Check default rate by is_not_employed
-- Expect: 0 -> 252137 applicants, 8.66% | 1 -> 55374 applicants, 5.40%
-- The average of a 0/1 column is the share of 1s, so AVG(target) is the default rate
-- The not-employed group defaults less, which is why we kept a flag as well as the NULL
SELECT
    is_not_employed,
    COUNT(*)                      AS applicants,
    ROUND(100.0 * AVG(target), 2) AS default_rate_pct
FROM clean.application_train
GROUP BY is_not_employed
ORDER BY is_not_employed;

-- 10. Check that real missing values were carried over unchanged
-- Expect: fam_nulls 2, car_age_nulls 202929, req_year_nulls 41519,
--         totalarea_nulls 148431, ext1_nulls 173378
-- These columns were only copied or cast, so cleaning must not add or lose NULLs
SELECT
    COUNT(*) - COUNT(cnt_fam_members)            AS fam_nulls,
    COUNT(*) - COUNT(own_car_age)                AS car_age_nulls,
    COUNT(*) - COUNT(amt_req_credit_bureau_year) AS req_year_nulls,
    COUNT(*) - COUNT(totalarea_mode)             AS totalarea_nulls,
    COUNT(*) - COUNT(ext_source_1)               AS ext1_nulls
FROM clean.application_train;
