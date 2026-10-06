"""Build the Lumo warehouse end to end: load, transform, export.

Usage (from this directory, with the project virtualenv active):
    python scripts/run_data_challenge.py
"""

import subprocess
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT.parent / "data"
OUTPUTS = ROOT / "outputs"
DATABASE = OUTPUTS / "lumo.duckdb"

# Business questions and Gold models exported after the build.
ANALYSES = [
    "q1_applications_approval",
    "q2_loans_gmv",
    "q3_january_2026_cohort",
    "q4_fpd30",
    "q5_par30_balance",
    "q6_merchant_concentration",
    "q7_customers_redundant_ids",
]
GOLD = {
    "agg_merchant_monthly": "merchant_id, month",
    "dm_loan_delinquency_snapshot": "loan_id",
}


def load_raw() -> None:
    """Load the seven source CSVs into DuckDB's raw (Bronze) schema."""
    files = sorted(DATA.glob("raw_*.csv"))
    if len(files) != 7:
        raise RuntimeError(f"expected 7 raw CSV files, found {len(files)}")

    OUTPUTS.mkdir(exist_ok=True)
    with duckdb.connect(str(DATABASE)) as connection:
        connection.execute("create schema if not exists raw")
        for path in files:
            # Everything stays text so the raw layer keeps the exact source values.
            connection.execute(
                f"create or replace table raw.{path.stem} as "
                "select * from read_csv(?, header=true, all_varchar=true)",
                [str(path)],
            )
            row = connection.execute(
                f"select count(*) from raw.{path.stem}"
            ).fetchone()
            assert row is not None  # count(*) always yields exactly one row
            count = row[0]
            print(f"{path.name}: {count:,} rows")


def run_dbt() -> None:
    """Build the models and tests, then compile the report analyses."""
    dbt = str(Path(sys.executable).with_name("dbt"))
    # `build` runs models and tests; `compile` writes the analyses for export.
    for command in ("build", "compile"):
        subprocess.run(
            [dbt, command, "--project-dir", ".", "--profiles-dir", "."],
            cwd=ROOT,
            check=True,
        )


def export(connection: duckdb.DuckDBPyConnection, sql: str, name: str) -> None:
    """Let DuckDB write one query result straight to CSV."""
    path = OUTPUTS / f"{name}.csv"
    connection.execute(f"copy ({sql}) to '{path}' (header, delimiter ',')")
    print(f"exported {path.name}")


def export_results() -> None:
    """Export the seven answers and the two Gold models."""
    compiled = ROOT / "target" / "compiled" / "lumo" / "analyses"
    with duckdb.connect(str(DATABASE), read_only=True) as connection:
        for name in ANALYSES:
            sql = (compiled / f"{name}.sql").read_text().strip().rstrip(";")
            export(connection, sql, name)
        for name, order_by in GOLD.items():
            export(connection, f"select * from lumo_gold.{name} order by {order_by}", name)


def main() -> None:
    # Each step feeds the next: raw tables, then models, then exports.
    load_raw()
    run_dbt()
    export_results()


if __name__ == "__main__":
    main()
