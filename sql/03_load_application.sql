-- 03_load_application.sql
-- Load application_train.csv into raw.application_train, as-is.
-- Grain: one row per loan application (sk_id_curr). Includes TARGET
-- (1 = payment difficulties, 0 = otherwise). 122 columns.
-- Typing rule for raw tables: IDs and TARGET are INTEGER, labels are TEXT,
-- and every other number is NUMERIC so values load exactly as written.
-- Tighter types are applied during cleaning.
-- Column ORDER must match the CSV header exactly (COPY matches by position).
-- Verified against the real header: same 122 names in the same order.
-- Expected rows: 307,511

\timing on

CREATE SCHEMA IF NOT EXISTS raw;

DROP TABLE IF EXISTS raw.application_train;

CREATE TABLE raw.application_train (
    -- Keys and label
    sk_id_curr                    INTEGER,
    target                        INTEGER,

    -- The loan and the applicant
    name_contract_type            TEXT,
    code_gender                   TEXT,
    flag_own_car                  TEXT,     -- Y / N
    flag_own_realty               TEXT,     -- Y / N
    cnt_children                  NUMERIC,
    amt_income_total              NUMERIC,
    amt_credit                    NUMERIC,
    amt_annuity                   NUMERIC,
    amt_goods_price               NUMERIC,
    name_type_suite               TEXT,
    name_income_type              TEXT,
    name_education_type           TEXT,
    name_family_status            TEXT,
    name_housing_type             TEXT,
    region_population_relative    NUMERIC,
    days_birth                    NUMERIC,
    days_employed                 NUMERIC,  -- watch for 365243 placeholder
    days_registration             NUMERIC,
    days_id_publish               NUMERIC,
    own_car_age                   NUMERIC,

    -- Contact flags (0/1)
    flag_mobil                    NUMERIC,
    flag_emp_phone                NUMERIC,
    flag_work_phone               NUMERIC,
    flag_cont_mobile              NUMERIC,
    flag_phone                    NUMERIC,
    flag_email                    NUMERIC,

    -- Work, household, region, application timing
    occupation_type               TEXT,
    cnt_fam_members               NUMERIC,
    region_rating_client          NUMERIC,
    region_rating_client_w_city   NUMERIC,
    weekday_appr_process_start    TEXT,
    hour_appr_process_start       NUMERIC,
    reg_region_not_live_region    NUMERIC,
    reg_region_not_work_region    NUMERIC,
    live_region_not_work_region   NUMERIC,
    reg_city_not_live_city        NUMERIC,
    reg_city_not_work_city        NUMERIC,
    live_city_not_work_city       NUMERIC,
    organization_type             TEXT,

    -- External credit scores (normalised)
    ext_source_1                  NUMERIC,
    ext_source_2                  NUMERIC,
    ext_source_3                  NUMERIC,

    -- Building statistics: averages
    apartments_avg                NUMERIC,
    basementarea_avg              NUMERIC,
    years_beginexpluatation_avg   NUMERIC,
    years_build_avg               NUMERIC,
    commonarea_avg                NUMERIC,
    elevators_avg                 NUMERIC,
    entrances_avg                 NUMERIC,
    floorsmax_avg                 NUMERIC,
    floorsmin_avg                 NUMERIC,
    landarea_avg                  NUMERIC,
    livingapartments_avg          NUMERIC,
    livingarea_avg                NUMERIC,
    nonlivingapartments_avg       NUMERIC,
    nonlivingarea_avg             NUMERIC,

    -- Building statistics: modes
    apartments_mode               NUMERIC,
    basementarea_mode             NUMERIC,
    years_beginexpluatation_mode  NUMERIC,
    years_build_mode              NUMERIC,
    commonarea_mode               NUMERIC,
    elevators_mode                NUMERIC,
    entrances_mode                NUMERIC,
    floorsmax_mode                NUMERIC,
    floorsmin_mode                NUMERIC,
    landarea_mode                 NUMERIC,
    livingapartments_mode         NUMERIC,
    livingarea_mode               NUMERIC,
    nonlivingapartments_mode      NUMERIC,
    nonlivingarea_mode            NUMERIC,

    -- Building statistics: medians
    apartments_medi               NUMERIC,
    basementarea_medi             NUMERIC,
    years_beginexpluatation_medi  NUMERIC,
    years_build_medi              NUMERIC,
    commonarea_medi               NUMERIC,
    elevators_medi                NUMERIC,
    entrances_medi                NUMERIC,
    floorsmax_medi                NUMERIC,
    floorsmin_medi                NUMERIC,
    landarea_medi                 NUMERIC,
    livingapartments_medi         NUMERIC,
    livingarea_medi               NUMERIC,
    nonlivingapartments_medi      NUMERIC,
    nonlivingarea_medi            NUMERIC,

    -- Building statistics: categorical
    fondkapremont_mode            TEXT,
    housetype_mode                TEXT,
    totalarea_mode                NUMERIC,
    wallsmaterial_mode            TEXT,
    emergencystate_mode           TEXT,

    -- Social circle defaults
    obs_30_cnt_social_circle      NUMERIC,
    def_30_cnt_social_circle      NUMERIC,
    obs_60_cnt_social_circle      NUMERIC,
    def_60_cnt_social_circle      NUMERIC,
    days_last_phone_change        NUMERIC,

    -- Documents provided (0/1)
    flag_document_2               NUMERIC,
    flag_document_3               NUMERIC,
    flag_document_4               NUMERIC,
    flag_document_5               NUMERIC,
    flag_document_6               NUMERIC,
    flag_document_7               NUMERIC,
    flag_document_8               NUMERIC,
    flag_document_9               NUMERIC,
    flag_document_10              NUMERIC,
    flag_document_11              NUMERIC,
    flag_document_12              NUMERIC,
    flag_document_13              NUMERIC,
    flag_document_14              NUMERIC,
    flag_document_15              NUMERIC,
    flag_document_16              NUMERIC,
    flag_document_17              NUMERIC,
    flag_document_18              NUMERIC,
    flag_document_19              NUMERIC,
    flag_document_20              NUMERIC,
    flag_document_21              NUMERIC,

    -- Credit bureau enquiries before application
    amt_req_credit_bureau_hour    NUMERIC,
    amt_req_credit_bureau_day     NUMERIC,
    amt_req_credit_bureau_week    NUMERIC,
    amt_req_credit_bureau_mon     NUMERIC,
    amt_req_credit_bureau_qrt     NUMERIC,
    amt_req_credit_bureau_year    NUMERIC
);

COPY raw.application_train
FROM '/data/raw/application_train.csv'
WITH (FORMAT csv, HEADER true);
