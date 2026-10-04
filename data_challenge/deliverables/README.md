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
Git. Source loading and transformation models will be added separately.
