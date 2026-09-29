-- 04_clean_application.sql
-- Build clean.application_train from raw.application_train.
-- Grain: one row per applicant (307,511 rows in and out), 37 columns.
-- Fixes:
--   placeholders become NULL (365243, XNA, Unknown),
--   Y/N becomes 1/0,
--   whole-number columns become INTEGER,
--   negative day counts become ages and years.

\timing on

CREATE SCHEMA IF NOT EXISTS clean;

DROP TABLE IF EXISTS clean.application_train;

CREATE TABLE clean.application_train AS
SELECT
    -- ------------------------------------------------------------------
    -- KEYS AND LABEL
    --   Who the applicant is, and what the model predicts.
    --   target: 1 = had payment difficulties. Unchanged.
    -- ------------------------------------------------------------------
    sk_id_curr,
    target,


    -- ------------------------------------------------------------------
    -- LOAN
    --   The loan being applied for: type, amount, repayment, goods price.
    --   Unchanged.
    -- ------------------------------------------------------------------
    name_contract_type,
    amt_credit,
    amt_annuity,
    amt_goods_price,


    -- ------------------------------------------------------------------
    -- WORK AND INCOME
    --   Income, job and employment.
    --   Changed: the employment placeholder 365243 becomes a flag plus NULL.
    -- ------------------------------------------------------------------
    -- income and job type: unchanged
    amt_income_total,
    name_income_type,
    occupation_type,

    -- organization_type: 'XNA' means no employer, so replace with NULL
    NULLIF(organization_type, 'XNA') AS organization_type,

    -- days_employed = 365243 means "not employed": keep that as a 1/0 flag
    CASE WHEN days_employed = 365243 THEN 1 ELSE 0 END AS is_not_employed,

    -- years employed: placeholder to NULL, then days to positive years
    -NULLIF(days_employed, 365243) / 365.25 AS years_employed,


    -- ------------------------------------------------------------------
    -- PERSON AND HOUSEHOLD
    --   Age, family, education and housing.
    --   Changed: placeholders to NULL, counts to INTEGER, days of birth to age.
    -- ------------------------------------------------------------------
    -- age: days before application to positive years
    -days_birth / 365.25 AS age_years,

    -- household counts: to INTEGER
    cnt_children::INTEGER AS cnt_children,
    cnt_fam_members::INTEGER AS cnt_fam_members,

    -- family status: 'Unknown' to NULL
    NULLIF(name_family_status, 'Unknown') AS name_family_status, 

    -- gender: 'XNA' to NULL
    NULLIF(code_gender, 'XNA') AS code_gender,

    -- education and housing: unchanged
    name_education_type,
    name_housing_type,


    -- ------------------------------------------------------------------
    -- ASSETS
    --   Car and property ownership.
    --   Changed: Y/N to 1/0, car age to INTEGER.
    -- ------------------------------------------------------------------
    -- ownership flags: Y/N to 1/0
    CASE flag_own_car WHEN 'Y' THEN 1 WHEN 'N' THEN 0 END AS flag_own_car,
    CASE flag_own_realty WHEN 'Y' THEN 1 WHEN 'N' THEN 0 END AS flag_own_realty,

    -- car age in years: to INTEGER
    own_car_age::INTEGER AS own_car_age,


    -- ------------------------------------------------------------------
    -- REGION
    --   Where the applicant lives.
    --   Population density unchanged; region rating (1-3) to INTEGER.
    -- ------------------------------------------------------------------
    region_population_relative,
    region_rating_client_w_city::INTEGER AS region_rating_client_w_city,


    -- ------------------------------------------------------------------
    -- EXTERNAL CREDIT SCORES
    --   Normalised scores (0 to 1) from outside sources.
    --   Usually the strongest predictors. Unchanged.
    -- ------------------------------------------------------------------
    ext_source_1,
    ext_source_2,
    ext_source_3,


    -- ------------------------------------------------------------------
    -- DATES
    --   Days before the application that details last changed.
    --   Changed: to INTEGER (one value rounded first).
    -- ------------------------------------------------------------------
    -- 408583: registration = birth date + 1 hour (date-time artefact): rounding recovers the intended value
    ROUND(days_registration)::INTEGER AS days_registration,

    -- ID document and phone number changes: to INTEGER
    days_id_publish::INTEGER AS days_id_publish,
    days_last_phone_change::INTEGER AS days_last_phone_change,


    -- ------------------------------------------------------------------
    -- SOCIAL CIRCLE
    --   Defaults among the applicant's contacts (30 and 60 days past due).
    --   Changed: to INTEGER.
    -- ------------------------------------------------------------------
    def_30_cnt_social_circle::INTEGER AS def_30_cnt_social_circle,
    def_60_cnt_social_circle::INTEGER AS def_60_cnt_social_circle,


    -- ------------------------------------------------------------------
    -- DOCUMENTS AND CONTACT
    --   0/1 flags: document 3 provided, work phone given.
    --   Changed: to INTEGER.
    -- ------------------------------------------------------------------
    flag_document_3::INTEGER AS flag_document_3,
    flag_work_phone::INTEGER AS flag_work_phone,


    -- ------------------------------------------------------------------
    -- CREDIT BUREAU ENQUIRIES
    --   How often lenders checked the credit file in the quarter and year
    --   before the application. Changed: to INTEGER.
    -- ------------------------------------------------------------------
    amt_req_credit_bureau_qrt::INTEGER AS amt_req_credit_bureau_qrt,
    amt_req_credit_bureau_year::INTEGER AS amt_req_credit_bureau_year,


    -- ------------------------------------------------------------------
    -- BUILDING
    --   One summary of the applicant's building, standing in for all 47
    --   building columns. Unchanged.
    -- ------------------------------------------------------------------
    totalarea_mode

FROM raw.application_train;