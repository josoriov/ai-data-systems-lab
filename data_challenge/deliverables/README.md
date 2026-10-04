# Lumo lending analytics

This project uses dbt and DuckDB for a local warehouse over synthetic lending
data. The configuration defines Silver and Gold schemas and a reporting cutoff
of **2026-06-30**. DuckDB stores its database at `outputs/lumo.duckdb` and uses UTC
for its session timezone; business-date transformations use `America/Bogota`.

## Environment

From this directory, create a Python 3.13 environment with `uv` and install the
pinned dependencies:

```sh
test -x ../../.venv/bin/python || uv venv --python 3.13 ../../.venv
uv pip install --python ../../.venv/bin/python -r requirements.txt
```

The profile and project configuration are in `profiles.yml` and
`dbt_project.yml`. Database files, logs, and dbt build artifacts are ignored by
Git. Transformation models are added separately from source loading.


## Load the source data

From this directory, run:

```sh
../../.venv/bin/python scripts/run_data_challenge.py
```

The loader recreates seven tables in DuckDB's `raw` schema from the CSVs in
`../data/`. All columns are loaded as text; source values and duplicate rows
remain available for later transformations. The command prints each table's
row count and can be run again to reload the inputs.

The source declarations in `models/sources.yml` describe each raw table. The
loader only imports raw data at this stage; it does not build models or export
reports.
