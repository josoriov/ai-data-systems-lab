#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")"
command -v uv >/dev/null 2>&1 || { echo "uv is required to run this project" >&2; exit 1; }
test -x .venv/bin/python || uv venv --python 3.13 .venv
uv pip install --python .venv/bin/python -r requirements.txt
exec .venv/bin/python triage.py "$@"
