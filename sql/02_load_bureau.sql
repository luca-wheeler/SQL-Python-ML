-- 02_load_bureau.sql
-- Load bureau.csv into raw.bureau, as-is.
-- Grain: one row per loan the applicant has (or had) at ANOTHER lender,
-- as reported by the credit bureau. Many rows per applicant (sk_id_curr).
-- Typing rule for raw tables: IDs are INTEGER, labels are TEXT, and every
-- other number is NUMERIC so values like -153.0 load exactly as written.
-- Tighter types (e.g. INTEGER days) are applied during cleaning.
-- Expected rows: 1,716,428

\timing on

CREATE SCHEMA IF NOT EXISTS raw;

DROP TABLE IF EXISTS raw.bureau;

CREATE TABLE raw.bureau (
    sk_id_curr              NUMERIC,   -- applicant (joins to application_train)
    sk_id_bureau            NUMERIC,   -- this bureau loan
    credit_active           TEXT,      -- e.g. Active, Closed
    credit_currency         TEXT,      -- e.g. currency 1
    days_credit             NUMERIC,   -- days before application the loan started
    credit_day_overdue      NUMERIC,   -- days overdue at application time
    days_credit_enddate     NUMERIC,   -- planned end date (can be in the future)
    days_enddate_fact       NUMERIC,   -- actual end date (closed loans only)
    amt_credit_max_overdue  NUMERIC,   -- largest amount ever overdue
    cnt_credit_prolong      NUMERIC,   -- times the loan was extended
    amt_credit_sum          NUMERIC,   -- total loan amount
    amt_credit_sum_debt     NUMERIC,   -- current debt
    amt_credit_sum_limit    NUMERIC,   -- credit limit (cards)
    amt_credit_sum_overdue  NUMERIC,   -- amount currently overdue
    credit_type             TEXT,      -- e.g. Consumer credit, Credit card
    days_credit_update      NUMERIC,   -- days before application of last update
    amt_annuity             NUMERIC    -- regular repayment
);

COPY raw.bureau
FROM '/data/raw/bureau.csv'
WITH (FORMAT csv, HEADER true);
