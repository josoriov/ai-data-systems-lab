# Lumo lending analytics

A local dbt project on DuckDB. The seven CSVs are loaded as text into the `raw`
schema (Bronze), without business transformations. dbt builds the Silver and
Gold models, and the seven business answers are exported next to the two Gold
models.

## Run in three commands

This requires `uv`; the first command creates a Python 3.13 environment if it
does not already exist.

From this directory:

```sh
test -x ../../.venv/bin/python || uv venv --python 3.13 ../../.venv
uv pip install --python ../../.venv/bin/python -r requirements.txt
../../.venv/bin/python scripts/run_data_challenge.py
```

The last command loads the CSVs, runs `dbt build` and `dbt compile`, and writes
the seven answers plus `agg_merchant_monthly` and `dm_loan_delinquency_snapshot`
to `outputs/`. It is safe to run again from scratch.

## Lineage

- **Bronze** — the seven source tables in DuckDB's `raw` schema, kept as text.
- **Silver** — the six required entities (`dim_customer`, `dim_merchant`,
  `fct_application`, `fct_loan`, `fct_payment`, `fct_installment_status`) plus
  two intermediates that those models share: `int_payment_history` (payment
  normalization and reversals) and `int_installment_status` (FIFO allocation at
  every month-end, used for monthly PAR30).
- **Gold** — `agg_merchant_monthly` and `dm_loan_delinquency_snapshot`.
- **Answers** — the seven `analyses/q*.sql` files produce CSV reports.

`agg_merchant_monthly` joins `dim_merchant` on the version active on each event
date (application, disbursement, or snapshot), so metrics respect the category
a merchant held at the time. The result stays at the required
`merchant_id × month` grain.

## Notes on the implementation

- Python only loads the CSVs, drives dbt, and exports results. The business
  logic lives in dbt SQL. The load and export use DuckDB's native CSV reader and
  writer, so pandas/numpy would add a dependency without shortening the code.
- Money is converted with `decimal` arithmetic and stored at a fixed scale, so
  totals are exact and reproducible instead of accumulating float noise.
- FIFO payment allocation is one set-based model, not a row-by-row loop: see the
  header comment in `models/silver/int_installment_status.sql`.
