# Project brief

AI & Data Systems Lab explores two workflows for **Lumo**, a fictional
consumer-lending company: turning operational extracts into consistent
analytics, and turning incoming support messages into structured routing
decisions. The implementation is built around supplied synthetic datasets and
example policies.

## Lending analytics

The source data represents credit applications, disbursed loans, installment
schedules, payments from two systems, customers, merchant history, and exchange
rates. It intentionally includes duplicates, inconsistent timestamp formats,
reversals, and incomplete records.

The warehouse uses three layers:

1. **Bronze:** load all seven CSVs into DuckDB's `raw` schema as text, preserving
   source values and duplicates before transformation.
2. **Silver:** resolve customer identities, derive merchant history, select final
   application states, identify valid loans and payments, and allocate payments
   to installments.
3. **Gold:** produce monthly merchant performance and a loan-level delinquency
   snapshot for **2026-06-30**.

### Business rules

- Interpret source timestamps as UTC and derive business dates in
  `America/Bogota`. Installment due dates are already local dates.
- Exclude deleted applications and loans without a valid approved application.
- Identify people by document number, allowing multiple technical customer IDs.
- Match merchant attributes to the version valid on each event's date.
- Normalize legacy payment references and minor-unit amounts; resolve payment
  reversals within their source system and respect their effective dates.
- Allocate received money to the oldest installments first (FIFO). Partial
  payments and payments spanning multiple installments must conserve money.
- Convert disbursed principal to USD using the latest available exchange rate on
  or before disbursement; convert snapshot balances at the reporting cutoff.
- Calculate loan days past due (DPD) from its oldest unpaid installment.
- Measure first-payment default (FPD30) among loans whose first installment has
  reached the 30-day observation window. Default requires more than 30 days late.
- Calculate portfolio at risk (PAR30) as outstanding USD balance on loans more
  than 30 days past due divided by total outstanding USD balance.

### Questions answered

1. How many valid applications were approved, and what is the approval rate?
2. How many valid loans were disbursed, and what is their total principal in USD?
3. What are the loan count and USD principal for the January 2026 cohort?
4. What is FPD30 overall and for that cohort?
5. What are outstanding balance and PAR30 at the reporting cutoff?
6. How concentrated is disbursed principal among the top five merchants?
7. How many distinct people and redundant customer IDs appear in the source?

The output contract consists of documented model grains, SQL answer queries,
CSV exports, and reconciled results. Quality checks cover keys, relationships,
accepted values, rates, reversal targets, and FIFO conservation. Detailed source
semantics are in the [data dictionary](data_challenge/data/data_dictionary.md);
implementation choices are in the [assumptions](data_challenge/deliverables/ASSUMPTIONS.md).

## Customer-message triage

The input is 340 synthetic Spanish messages across chat, email, and WhatsApp.
Each JSONL record contains an ID, channel, received timestamp, sender, and text.
Messages include multiple intents, informal language, ambiguous requests, and
noise. The illustrative scale target is **10,000 messages/day**; this is a design
scenario, not measured throughput or a claim about a deployed system.

For each message, the component produces:

- A primary contact reason, secondary intents, and priority.
- Extracted entities supported by the message text.
- An action: automatic reply, human escalation, or discard.
- A queue when human handling is required.
- Relevant policy references and a Spanish draft when an automatic reply is safe.
- A technical status so processing failures remain visible.

The model interprets language and proposes structured decisions. Python then
enforces routing, evidence, and policy-coverage rules. Fraud, account-specific
lookups, and unsupported actions require human handling. Reply templates use
fictional policy text; missing coverage must not be filled with invented advice.
The batch output includes per-message rows and reconciled summary counts.

The [taxonomy](ai_challenge/taxonomy.md) defines contact reasons, and the
[knowledge base](ai_challenge/knowledge_base/README.md) contains fictional policies
with intentional gaps. The [AI project guide](ai_challenge/README.md) explains
the implementation and its limits.

## Scope and reproducibility

Both systems run from local files. The warehouse needs no cloud account; live
triage needs the user's own provider key. Existing outputs make the results
inspectable without executing either pipeline. Automated data checks and offline
triage tests validate deterministic behavior; labelled model evaluation,
throughput testing, deployment, and incremental processing remain future work.
