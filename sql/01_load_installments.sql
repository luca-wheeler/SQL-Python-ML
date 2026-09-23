-- 01_load_installments.sql

-- Load installments_payments.csv
-- (one row per instalment payment on a previous Home Credit loan)
-- into Postgres skas is
-- Days and version columns are NUMERIC because the CSV writes them as 1.0; converted during cleaning.
-- Cleaning comes later

\timing on

DROP TABLE IF EXISTS installments_payments;

CREATE TABLE installments_payments (
    sk_id_prev              INTEGER,
    sk_id_curr              INTEGER,
    num_installment_version  NUMERIC,
    num_installment_number   INTEGER,
    days_installment         NUMERIC,
    days_entry_payment      NUMERIC,
    amt_installment          NUMERIC,
    amt_payment             NUMERIC
);

COPY installments_payments
FROM '/data/raw/installments_payments.csv'
WITH (FORMAT csv, HEADER true);