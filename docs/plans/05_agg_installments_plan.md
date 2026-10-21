# Plan: `05_agg_installments.sql` and `05_checks.sql`

**Status:** Draft, awaiting Luca's decisions (see *Open decisions*) · **Written:** 29 September 2026
**Reference:** Credit Risk SQL Workbook, file 05 (sections 05.1 to 05.6)

## Session goals

1. Plan `sql/05_agg_installments.sql`: understand its purpose, its effect on the ML, and how each query works.
2. Plan `sql/05_checks.sql`: understand how each check was discovered and what it proves.
3. Write the check-results document and the decision record.
4. Write a few lines of context for the 06 session.

Nothing below has been written yet except this plan.

## Current state of the repo

- `sql/05_agg_installments.sql`: Luca's skeleton (header, `\timing on`, schema, `DROP`, `CREATE TABLE … AS`, empty `WITH cleaned AS ( )`). Untracked.
- `05_checks.sql`: exists in the **repo root**, not in `sql/`. Untracked. Other checks files live in `sql/`, so it probably needs moving (Luca's call).
- `docs/checks/01_installments_checks.md` still has ⏳ rows (checks 3, 4b, 4c).

## 1. Why this file exists

The model needs **one row per applicant**, with features as columns. `raw.installments_payments` has 13,605,401 rows, **one per payment**, so one applicant has many rows. Joining it directly onto `clean.application_train` would copy each applicant once per payment (fan-out) and corrupt the row count and labels.

This file collapses each applicant's payment history into 7 behaviour features plus the key `sk_id_curr` (8 columns). The output is `features.installments_by_applicant`, which file 07 joins into the final feature table.

| Feature | Meaning | Why it might predict default |
|---|---|---|
| `inst_n_payments` | Number of payment rows | Amount of history; thin files are risky |
| `inst_n_prev_loans` | Number of different earlier loans | Breadth of history |
| `inst_n_missed` | Payments due but never made (no payment date) | Direct evidence of non-payment |
| `inst_avg_days_late` | Average days late, over paid rows, 2 dp | Typical repayment habit |
| `inst_max_days_late` | Worst lateness | One very bad episode that an average hides |
| `inst_share_late` | Late rows ÷ paid rows, 4 dp | Consistency of lateness |
| `inst_pay_ratio` | Total paid ÷ total due, 4 dp | Underpayment |

### How it affects the ML

- **Behaviour beats profile.** `application_train` describes who someone is. This table describes how they repaid before, which usually predicts default better.
- **Aggregation is lossy.** Each feature is a different summary of the same pile of rows. Mean, max and share capture different things.
- **NULLs are meaningful.**
  - 15,868 training applicants have no installment history. File 07 gives them NULLs through a `LEFT JOIN`.
  - LightGBM handles NULLs natively. Logistic regression needs imputation, which must happen inside the CV `Pipeline` to avoid leakage.
- **Leakage.** These are previous loans and must all be before the application date. Verified: latest due day and latest paid day are both **−1**.

## 2. How each query works

`days_late = days_entry_payment − days_installment`. Both are negative day offsets, so paid minus due is positive when late, negative when early, NULL when never paid.

### Stage 1: `WITH cleaned AS (…)` (one row per payment, no grouping)

- Keep `sk_id_curr`, `sk_id_prev`, `amt_installment`, `amt_payment`.
- `days_entry_payment::INTEGER AS days_paid`. Safe because whole-number checks found 0 non-whole values. NULL stays NULL.
- `(days_entry_payment - days_installment)::INTEGER AS days_late`. Subtraction first, then cast.
- `NULL − number = NULL`, so never-paid rows get a NULL `days_late`.

### Stage 2: `SELECT … GROUP BY sk_id_curr` (one row per applicant)

Every column except `sk_id_curr` must be an aggregate.

| Expression | The subtle point |
|---|---|
| `COUNT(*)` vs `COUNT(days_late)` | `*` counts every row; a column name counts only non-NULL values, which gives paid rows |
| `COUNT(*) FILTER (WHERE days_paid IS NULL)` | Counts only unpaid rows. Use `IS NULL`, never `= NULL` |
| `COUNT(DISTINCT sk_id_prev)` | Different earlier loans, not payments |
| `ROUND(AVG(days_late), 2)` | `AVG` skips NULLs, so averages over paid rows only. That is why `inst_n_missed` is counted separately. All-missed applicants get NULL |
| `MAX(days_late)` | Integer in, integer out, no `ROUND`. Ignores NULL |
| `ROUND(COUNT(*) FILTER (WHERE days_late > 0)::NUMERIC / NULLIF(COUNT(days_late), 0), 4)` | `::NUMERIC` avoids integer division (1/3 = 0). `NULLIF(…, 0)` avoids divide-by-zero for applicants with no paid rows |
| `ROUND(SUM(amt_payment) / NULLIF(SUM(amt_installment), 0), 4)` | `SUM` skips the NULL amounts of unpaid rows, which correctly lowers the ratio. Both columns are NUMERIC, so no integer-division trap |

### Maths and concepts to study

- Mean, maximum, and a proportion: share = late count ÷ paid count.
- A ratio and its denominator edge cases (division by zero).
- Aggregation as information loss: many rows to one number.
- How NULL propagates: arithmetic with NULL gives NULL, `AVG` and `SUM` skip NULL, `COUNT(col)` skips NULL.
- Integer versus decimal division.

## 3. `05_checks.sql` plan

Each check comes from an earlier finding, or from a way the formulas could break.

| # | Check | Where it comes from | What it proves | Expected |
|---|---|---|---|---|
| 1 | Rows = distinct `sk_id_curr` = raw distinct applicants | Raw grain is many rows per applicant | Grouping worked; nobody lost | All three equal (339,587) |
| 2 | Column count | 04 check 2 | Shape is right | 8 |
| 3 | `SUM(inst_n_payments)`, `SUM(inst_n_missed)` | 01 checks 1 to 3 | Grouping neither creates nor destroys rows | 13,605,401 and 2,905 |
| 4 | Ranges: share in [0, 1]; prev loans ≤ payments; max ≥ avg | The formulas themselves | Catches integer-division and denominator bugs | min_payments ≥ 1; share in [0, 1]; both bad-row counts 0 |
| 5 | NULL averages only for all-missed applicants | Found this session: 9 applicants never paid | NULLs are explained, not accidental | Both counts equal (9) |
| 6 | Hand-check applicant 100002 against a raw recompute | Independent computation | Logic is right for a real case | Matching numbers |
| 7 | Latest due and paid day are negative | Leakage rule in `CLAUDE.md` | Nothing from after the application | −1 and −1 |
| 8 | Column types | 04 check 9 | Types as intended; `sk_id_curr` matches the clean table | `sk_id_curr` integer |
| 9 | Default rate by lateness bucket, and by has-history | 04 check 10 | Features carry signal; ties to the ML | Value to be recorded |

Possible extra: NULL count per column (as in earlier files), so `inst_pay_ratio` NULLs are explained too.

## 4. Documents to create

- `docs/checks/05_agg_installments_checks.md`: same format as `04_clean_application_checks.md` (summary, results table, what each group proves, how it ties back to raw findings).
- `docs/decisions/05_installments_features.md`: same format as `04_column_selection.md`. Covers:
  - why these 7 features;
  - `NULLIF` and `FILTER` choices;
  - the INTEGER cast;
  - the outlier note;
  - the payments-versus-installments caveat (workbook N6: a two-level aggregation is a stretch improvement).
- Optional: fill the ⏳ rows in `docs/checks/01_installments_checks.md` (needs Luca's OK).

## 5. Context for the 06 session (draft)

> 05 is done: `features.installments_by_applicant` has one row per applicant with 7 `inst_*` features. Applicants with no history are simply absent from it, so file 07 must `LEFT JOIN` from `clean.application_train`; do not zero-fill the lateness features (NULL means "no history"). `sk_id_curr` is INTEGER in clean and features tables. For 06 (`06_agg_bureau.sql`): same pattern (CTE, then `GROUP BY sk_id_curr`, then checks). Leakage rule: exclude the 17 bureau rows dated after the application. Keep a `has_bureau_history` flag, because missing history is itself a signal (no-record applicants default at about 10.1% vs 7.7%).

## Facts found this session (raw `installments_payments`)

| Finding | Result |
|---|---|
| The 2,905 NULLs in `days_entry_payment` and `amt_payment` | Same rows; 0 rows with only one |
| Non-whole-number day values (paid and due) | 0 |
| Distinct applicants | 339,587 |
| Latest due day / latest paid day | −1 / −1 (no future data) |
| Earliest due day | −2,922 |
| Rows with `amt_installment = 0` | 290 |
| Rows with `amt_payment = 0` | 1,440 |
| Range of `days_late` | −3,189 to +2,884 |
| Late rows (`days_late > 0`) | 1,146,669 |
| Rows more than 365 days late | 4,886 (`MAX` is sensitive; consider a log or clip in Python for logistic regression) |
| Applicants who never paid anything | 9 |
| Training applicants with no installment history | 15,868 |
| `sk_id_curr` type | `integer` in `clean.application_train`, `NUMERIC` in `raw.installments_payments` |

**Not yet checked:** how many of the 339,587 applicants are in the training set. It does not affect the design, because file 07 starts from `clean.application_train`.

**Performance note:** `COUNT(DISTINCT …)` combined with `IN (SELECT …)` inside an aggregate ran for over 20 minutes on this table. Find the distinct IDs first (for example into a temp table), then compare. That version took about 1.6 seconds.

## Open decisions

1. **Who writes the SQL?** Luca writes T05.1 to T05.3 (max, share late, pay ratio) with hints and Claude fills in the rest (leaving `TODO(Luca)` markers), or Claude writes the whole file after approval.
2. **Cast `sk_id_curr::INTEGER` in the CTE?** Recommended, so file 07 joins like for like. The workbook's worked code does not do this.
3. **Fill in the ⏳ rows in the 01 checks doc?**
4. **Where does the 06 handoff live?** A file (survives `/clear`) or just text in the reply.
5. **Move `05_checks.sql` into `sql/`?**

## Order of work once approved

1. Finish `sql/05_agg_installments.sql` (per decision 1). Run it and note the row count.
2. Write and run `sql/05_checks.sql`. Record real results.
3. Write the checks doc and decision record.
4. Write the 06 handoff.
5. Show `git status` and suggest a one-line commit message. Luca stages and commits himself.
