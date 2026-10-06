# Technical decisions

The project READMEs explain what I built. This file covers the architecture,
business rules, and tradeoffs behind the implementation.

I treated both systems as local prototypes. My priority was to make the
important business rules visible and keep the results easy to reproduce.
Production infrastructure depends on deployment requirements outside this scope.

## Choices shared by both projects

### Why keep the projects local-first?

The data project runs against local files and needs no cloud account. The AI
project uses the reader's own provider key for live calls; its recorded output
and offline tests are available without one. This also made it easier for me to
rebuild the work from a clean environment while developing it.

### Why keep generated outputs in the repository?

Both projects produce results that are part of the answer. Committing the CSV
and JSON outputs lets readers inspect those results without first installing
dependencies or using an API key. Reproducible output matters more here than a
perfectly clean source-only repository.

I did not commit caches, virtual environments, dbt build artifacts, the DuckDB
database, or `.env` files. They are either local state or can be recreated.

### Why so few dependencies?

Every dependency adds setup time. I used a dependency when it removed real
work: dbt and DuckDB for the data models, and Pydantic plus the
official OpenAI SDK for typed API responses. The rest is Python's standard
library and SQL.

### Why no production infrastructure?

A queue, scheduler, cloud warehouse, secrets manager, monitoring stack, and CI
pipeline would all be reasonable in a real deployment. None can be designed
well without deployment requirements and operating constraints. The prototype
focuses on the business logic and local reproducibility.

## Lending analytics

### Why DuckDB instead of a cloud warehouse?

I wanted the project to be easy to reproduce on a laptop. DuckDB
runs in process, needs no account or server, and has a dbt adapter. Its SQL is
also close enough to PostgreSQL for this work, which matters because PostgreSQL
is the dialect I know best.

This is not a recommendation to replace production warehouses with DuckDB.
With the same dbt model structure, the target could be moved to a production
warehouse and the small dialect differences handled there.

### Why dbt when a Python script could run the SQL?

The project includes a transformation layer as well as final queries.
dbt makes dependencies, model grains, tests, and documentation visible. Python
only loads the raw files, calls dbt, and exports results; the business logic
stays in SQL where an analytics engineer would expect to find it.

### Why load every Bronze column as text?

Bronze is where I wanted to preserve the source shape and duplicate rows, not
where I wanted parsing failures to silently remove records. Loading columns as
text lets the Silver models make each cast and cleanup rule explicit. DuckDB's
CSV reader can still represent empty fields as null, so “no business
transformations” is more accurate than saying the files are byte-for-byte
unchanged.

### Why full refreshes instead of incremental models?

The supplied data fits comfortably on a laptop. Full refreshes are simpler to
reason about for FIFO allocation, reversals, and historical merchant versions,
and they naturally pick up late rows. I would add incremental strategies only
after volume or runtime made the extra state worthwhile.

### Why only two intermediate models?

`int_payment_history` is shared payment and reversal logic.
`int_installment_status` is the reusable monthly FIFO calculation. The other
transformations are used once, so splitting every CTE into its own dbt model
would add lineage without adding reuse.

### Why set-based FIFO instead of a Python loop?

Payments and installments can both be represented as cumulative ranges. Their
overlap gives the amount allocated to each installment. Keeping that operation
in SQL avoids moving data out of the warehouse and makes conservation and
ordering testable over the whole dataset.

The first version was more procedural. I kept the set-based rewrite only after
comparing both versions on all 1,230,323 rows.

### Why does a payment remain effective until its reversal date?

The models produce historical month-end balances. At a cutoff before the
reversal arrived, the payment was still part of the information available to
the business. From the reversal date onward, it no longer counts. The source
documentation does not state this point-in-time rule explicitly, so I recorded
it as an assumption rather than hiding it in SQL.

### Why use decimals and explicit ordering in sums?

Money should not change in the last decimal because a database processed rows
in a different order. I saw that happen with floating-point sums during the
work. Monetary values are therefore converted with decimals, and important
sums use stable ordering before being rounded for reporting.

Rates remain ratios rather than money. They are calculated from summed
numerators and denominators, never by averaging row-level rates.

### Why use the latest available FX rate on or before the transaction date?

The provider publishes rates only on business days. A weekend transaction
therefore uses the latest rate published on or before its business date. Using
a later rate would introduce information that was not yet available.

### Why derive SCD2 intervals instead of using a dbt snapshot?

The merchant source is already append-only and includes `valid_from`. The next
version's start date is enough to derive each half-open validity interval. A dbt
snapshot would store another history of data that is already historical.

### Why normalize UTC before deriving Bogotá dates?

The inputs mix several timestamp encodings, but they all describe UTC instants.
Parsing them first and then converting to `America/Bogota` avoids assigning
events near midnight to the wrong business day.

### Why keep the reporting cutoff in a dbt variable?

The reporting scenario fixes the cutoff at `2026-06-30`, so it is not runtime
business configuration. Keeping it in one dbt variable prevents slightly different
dates from being repeated across the FPD30, PAR30, and snapshot models.

More detailed business assumptions and data-quality findings are in
[`ASSUMPTIONS.md`](data_challenge/deliverables/ASSUMPTIONS.md).

## Message triage

### Why process one message per model call?

That matches the component defined in the brief and prevents one message from
affecting another. It also gives each result its own failure boundary. The batch
runner adds concurrency around the same single-message function and preserves
input order.

### Why `gpt-5.6-luna` with low reasoning effort?

The task is focused classification and extraction with an illustrative design
target of 10,000 messages a day. I started with the lower-cost model and low
reasoning effort because latency and cost matter at that volume. The choice is
provisional: with labelled examples, I would compare it against stronger models
using false automatic replies as the main quality metric.

### Why Structured Outputs and Pydantic?

The downstream ticketing system needs a predictable contract. Structured
Outputs and Pydantic remove most of the manual JSON parsing and reject fields
outside that contract.

A valid schema does not mean the business decision is correct. That is why the
typed model response still passes through deterministic safety rules.

### Why split model judgment from deterministic rules?

The model is useful for noisy Spanish, spelling mistakes, and multiple intents.
It should not decide alone whether to discard an in-scope message, send an
account-specific answer, or downgrade fraud. Those rules are short, testable,
and cheaper to enforce once in Python.

I deliberately did not build a full keyword classifier beside the model. The
few text checks only protect boundaries found during review, such as exact
account dates and unsupported certificate types.

### Why render replies from fixed policy text?

An early model-written draft added a detail that was not in the knowledge base.
For this prototype, the model selects the relevant policy sections and Python
renders reviewed wording from them. This is less flexible, but it makes the
automatic reply auditable.

### Why is the automation rate conservative?

The knowledge base is intentionally incomplete. A message that needs identity
validation, an account lookup, an action, or an unsupported policy should go to
a person. I would rather hand off a safe answer than confidently send a wrong
one. The recorded example batch automates about 14% of messages for that reason.

### Why eight worker threads?

Eight is not a capacity claim or a magic number. It made the sample finish in a
reasonable time while keeping the implementation simple, and the value is a
command-line option. Production concurrency should come from measured latency,
provider limits, and the queue design.

### Why omit the sender and set `store=False`?

The sender field is not needed to classify the text and is not verified
identity. Leaving it out avoids unnecessary personalization and reduces the
data sent to the model. `store=False` is another appropriate default for these
records.

The message body can still contain personal data. A production version would
need an approved provider and retention policy, plus a decision about redacting
document numbers and similar values before the call.

### Why one Python module rather than a service structure?

There is one entry point and one processing flow in this exercise. Splitting it
into controllers, providers, repositories, and interfaces would make navigation
harder without changing the result. I would separate modules when the component
gains another caller or independent responsibilities.

### Why are the tests offline?

The tests cover the contract and the deterministic safety boundaries. They do
not need a network call, should not cost money, and should return the same result
every time. Model quality needs a labelled evaluation set; disguising seven API
examples as unit tests would not provide that.

The implementation review and AI corrections are described in
[`HOW_I_WORKED.md`](ai_challenge/deliverables/HOW_I_WORKED.md).
