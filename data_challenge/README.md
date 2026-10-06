# Lending analytics warehouse

A local dbt and DuckDB project that turns synthetic consumer-lending extracts
into consistent business metrics for **Lumo**, a fictional company. The
[project brief](../PROJECT_BRIEF.md) defines the goals and reporting contracts.

## Source data

Seven CSVs represent operational systems with intentionally messy records:

| File | Contents |
|---|---|
| `raw_applications_cdc.csv` | Application state changes, deletes, and duplicates |
| `raw_loans.csv` | Disbursed loans, including invalid migration records |
| `raw_installments.csv` | Installment schedules |
| `raw_payments.csv` | Payments and reversals from two source systems |
| `raw_customers.csv` | Customer records with redundant identities |
| `raw_merchants_history.csv` | Append-only merchant attribute history |
| `raw_fx_rates.csv` | Exchange rates on business days |

The [data dictionary](data/data_dictionary.md) specifies fields and semantics.
All records are synthetic. Source timestamps represent UTC instants; reporting
dates use `America/Bogota`, with a fixed snapshot cutoff of **2026-06-30**.

## Warehouse layers

**Bronze** stores the source CSV columns as text in DuckDB's `raw` schema before
business transformations. **Silver** establishes reusable entity grains:

| Model | Grain and purpose |
|---|---|
| `dim_customer` | One person per document number |
| `dim_merchant` | One merchant attribute version per validity interval |
| `fct_application` | One final valid application state |
| `fct_loan` | One valid loan, including principal converted to USD |
| `fct_payment` | One effective payment per source system and payment ID |
| `fct_installment_status` | One loan and installment at the reporting cutoff |

Two intermediate models normalize payment history and calculate FIFO allocation
at reporting month-ends. **Gold** exposes two consumption models:

- `agg_merchant_monthly`: applications, approval rate, disbursements, USD
  principal, FPD30, and PAR30 by merchant and month. Merchant categories reflect
  the version active when each event occurred.
- `dm_loan_delinquency_snapshot`: outstanding USD balance, days past due, and
  delinquency bucket per loan at the cutoff.

The [model documentation](deliverables/models/schema.yml) declares grains,
columns, and quality tests. [Assumptions](deliverables/ASSUMPTIONS.md) explain
identity resolution, reversals, allocation, exchange rates, and rate denominators.

## Business questions and results

The [analysis queries](deliverables/analyses/) answer seven questions: application
approval, total lending volume, January 2026 disbursements, overall and cohort
FPD30, cutoff PAR30 and outstanding balance, merchant concentration, and customer
identity duplication.

[Results and reconciliations](deliverables/RESULTS.md) connect each answer to its
query and exported CSV. The dataset produces 27,955 valid loans and
USD 8,780,942.16 in disbursed principal; these describe the synthetic portfolio.

## Run and validate

Follow the [implementation guide](deliverables/README.md) to create the Python
environment and execute the complete pipeline. It loads the raw data, builds
the models, runs 49 dbt tests, and exports seven answer files and two Gold files.
The [business tests](deliverables/tests/) check reversal targets and FIFO
conservation and ordering.

The pipeline rebuilds the local dataset in full. Incremental materialization and
production orchestration are outside the prototype's scope.
[AI workflow notes](deliverables/AI_LOG.md) describe model development and review;
[technical decisions](../TECHNICAL_DECISIONS.md) explain the main tradeoffs.
