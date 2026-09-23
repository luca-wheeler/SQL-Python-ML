-- 01_load_installments.sql

-- Load installments_payments.csv
-- (one row per instalment payment on a previous Home Credit loan)
-- into Postgres skas is
-- Days and version columns are NUMERIC because the CSV writes them as 1.0; converted during cleaning.
-- Cleaning comes later

\timing on

CREATE SCHEMA IF NOT EXISTS raw;

DROP TABLE IF EXISTS raw.installments_payments;

CREATE TABLE raw.installments_payments (
    sk_id_prev              NUMERIC,
    sk_id_curr              NUMERIC,
    num_installment_version  NUMERIC,
    num_installment_number   NUMERIC,
    days_installment         NUMERIC,
    days_entry_payment      NUMERIC,
    amt_installment          NUMERIC,
    amt_payment             NUMERIC
);

COPY raw.installments_payments
FROM '/data/raw/installments_payments.csv'
WITH (FORMAT csv, HEADER true);