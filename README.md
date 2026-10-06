# AI & Data Systems Lab

A portfolio project using synthetic consumer-lending data. Two local prototypes
explore analytics engineering and AI-assisted customer support for **Lumo**, a
fictional buy-now-pay-later company.

The implementation combines Python, SQL, dbt, DuckDB, Pydantic, and the OpenAI
SDK. The datasets and example policies describe a fictional scenario; the
results below are demonstrations on that data.

## Architecture

![AI & Data Systems Lab architecture: synthetic lending CSVs pass through a local Python, dbt, and DuckDB warehouse to nine CSV reports. Separately, synthetic messages and fictional policies feed a Python triage batch, which calls OpenAI and applies deterministic rules before writing a JSON report.](docs/architecture/ai-data-systems-lab.svg)

[Interactive architecture diagram](docs/architecture/ai-data-systems-lab.html)
— download the HTML and open it in a browser to explore source references,
switch between light and dark themes, and export images.
The [diagram specification](docs/architecture/ai-data-systems-lab.architecture.json)
is included for reproducibility.

The two workflows run independently. In lending analytics, Python loads raw
files, invokes dbt to build and test the Bronze → Silver → Gold warehouse in
DuckDB, and exports the results. In message triage, Python validates inputs,
assembles policy context, and processes messages concurrently through the
OpenAI Responses API. Deterministic rules check the model's decisions before
Python writes the ordered results and summary.

Only live triage calls require a provider key. Routing decisions and reply drafts
are recorded locally; the prototype does not send replies or create tickets.

## Projects

| Project | What it does | Explore |
|---|---|---|
| Lending analytics | Normalizes CDC records, payment reversals, and merchant history into a Bronze → Silver → Gold warehouse; calculates lending and delinquency metrics. | [Project guide](data_challenge/README.md) · [Run instructions](data_challenge/deliverables/README.md) |
| Message triage | Classifies Spanish messages, extracts supported entities, routes cases to human queues, and drafts replies grounded in fictional policies. | [Project guide](ai_challenge/README.md) · [Run instructions](ai_challenge/deliverables/README.md) |

Read the [project brief](PROJECT_BRIEF.md) for the goals and data contracts, and
[technical decisions](TECHNICAL_DECISIONS.md) for the architecture and tradeoffs.

## Example results

- **Lending analytics:** 59,059 valid applications, 27,955 valid loans, and
  USD 8,780,942.16 in disbursed principal. PAR30 is 20.57% at the 2026-06-30
  cutoff. [Results and reconciliations](data_challenge/deliverables/RESULTS.md).
- **Message triage:** the recorded example run covers all 340 messages with
  49 automatic replies, 258 human escalations, and 33 discards. These are routing
  counts, not a measured classification-accuracy score.
  [Example output](ai_challenge/deliverables/outputs/triage_results.json).

## Run locally

Install `uv`; the setup commands create Python 3.13 environments and install
pinned dependencies. The data pipeline runs locally without cloud accounts.
From the repository root:

```sh
cd data_challenge/deliverables
test -x ../../.venv/bin/python || uv venv --python 3.13 ../../.venv
uv pip install --python ../../.venv/bin/python -r requirements.txt
../../.venv/bin/python scripts/run_data_challenge.py
```

The pipeline loads the sources, builds the models, runs the dbt tests, and
exports CSV results. The [data guide](data_challenge/deliverables/README.md)
describes rerunning it and the output locations.

For live message triage, follow the
[AI setup instructions](ai_challenge/deliverables/README.md): copy the example
environment file, supply your own OpenAI API key, and run `./run.sh`. Live runs
send message text to the provider and incur API usage. The recorded output can
be inspected without a key.

## Validation and scope

The data project has 49 dbt tests covering model keys, relationships, valid
values, payment reversals, and FIFO conservation. The AI project has eight
[offline tests](ai_challenge/deliverables/test_triage.py) that need no API key;
its [run guide](ai_challenge/deliverables/README.md) includes the test command.

These are local prototypes. AI accuracy needs a labelled evaluation set, and
the illustrative 10,000-messages/day target has not been load-tested. The data
pipeline rebuilds the supplied dataset rather than maintaining an incremental
production warehouse.

Development notes document [data assumptions](data_challenge/deliverables/ASSUMPTIONS.md),
[AI-assisted SQL work](data_challenge/deliverables/AI_LOG.md), and
[triage development and review](ai_challenge/deliverables/HOW_I_WORKED.md).

## License

The original source code and documentation in this repository are released
under the [MIT License](LICENSE). The synthetic datasets, fictional policy
documents, and generated outputs derived from them are not covered by that
license and remain subject to their own terms.
