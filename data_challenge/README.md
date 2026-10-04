# Lending analytics warehouse

A local dbt and DuckDB warehouse over synthetic consumer-lending data for
**Lumo**, a fictional company. The [project brief](../PROJECT_BRIEF.md) defines
the business questions and reporting contracts.

The planned sources cover application state changes, loans, installments,
payments from two systems, customers, merchant history, and exchange rates.
They include duplicates, reversals, and inconsistent source formats.

The warehouse will preserve source values in a raw Bronze layer, establish
clean entity grains in Silver, and expose merchant performance and loan
delinquency in Gold. Key rules include customer identity resolution, dated
merchant attributes, payment reversals, FIFO allocation, and as-of FX rates.

Reporting uses `America/Bogota` business dates and a fixed **2026-06-30**
snapshot cutoff. The intended outputs answer seven questions about approval,
disbursements, cohort performance, delinquency, merchant concentration, and
customer identity duplication. The initial scope is a full local rebuild with
quality checks and reproducible exports.
