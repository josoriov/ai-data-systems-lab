"""Load the seven synthetic lending CSVs into the local DuckDB warehouse.

Run from data_challenge/deliverables with the project environment active:
    python scripts/run_data_challenge.py
"""

from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT.parent / "data"
OUTPUTS = ROOT / "outputs"
DATABASE = OUTPUTS / "lumo.duckdb"


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


if __name__ == "__main__":
    load_raw()
