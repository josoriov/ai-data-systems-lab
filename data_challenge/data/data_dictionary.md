# Data dictionary — Bronze layer

All records in these extracts are synthetic and describe the fictional Lumo
lending scenario.

Cross-cutting notes:

- **All timestamps are in UTC.** Operations close in `America/Bogota`.
- Amounts are in the merchant's local currency (`COP` or `BRL`) unless stated otherwise.
- Extracts are produced by periodic dumps; **the same record may appear more than once** if a dump
  was reprocessed.

---

## `raw_applications_cdc.csv` — applications (change data capture)

A replica of the origination core's change log. Every state change of an application produces a
new row; an application's current state is that of its latest version.

| Column | Type | Notes |
|---|---|---|
| `application_id` | bigint | Application identifier. Not unique in this file. |
| `customer_id` | bigint | FK to `raw_customers`. |
| `merchant_id` | bigint | FK to `raw_merchants_history`. |
| `requested_amount` | decimal | Requested amount, local currency. |
| `currency` | string | `COP` \| `BRL`. |
| `status` | string | `CREATED` \| `APPROVED` \| `REJECTED`. |
| `approved_amount` | decimal | Only populated after the decision. |
| `event_at_utc` | string | When the change occurred in the source system. |
| `_op` | string | CDC operation: `I` insert, `U` update, **`D` delete**. |
| `_ingested_at_utc` | string | When the row landed on our platform. |

> `_op = 'D'` means the source system **deleted the application** (typically confirmed fraud or
> internal testing). A deleted application did not exist for business purposes.

---

## `raw_loans.csv` — disbursed loans

A loan originates from an approved application. **A loan with no valid associated application is a
corrupt record from an old migration and must not be considered.**

| Column | Type | Notes |
|---|---|---|
| `loan_id` | bigint | |
| `application_id` | bigint | FK to the originating application. |
| `customer_id`, `merchant_id` | bigint | Denormalized from the application. |
| `principal` | decimal | Disbursed principal, local currency. |
| `currency` | string | |
| `term_months` | int | Number of installments. |
| `apr` | decimal | Annual rate used to build the plan. |
| `disbursed_at_utc` | string | Disbursement timestamp. |
| `status` | string | |

---

## `raw_installments.csv` — installment plan

Grain: `loan_id × installment_number`. Generated at disbursement and never changed afterwards.

| Column | Type | Notes |
|---|---|---|
| `loan_id` | bigint | |
| `installment_number` | int | 1..`term_months`. |
| `due_date` | date | Due date (a business date, already in local time). |
| `amount_due` | decimal | Fixed installment; the last one absorbs the rounding remainder. |

---

## `raw_payments.csv` — payments

Payments are recorded **at the loan level**, not the installment level: the collections system
does not know which installment the money belongs to.

| Column | Type | Notes |
|---|---|---|
| `payment_id` | bigint | Payment identifier in its source system. |
| `loan_ref` | string | Reference to the loan. **Format depends on `source_system`.** |
| `paid_at_utc` | string | Payment timestamp. |
| `amount_raw` | decimal | Amount exactly as the source system delivers it (see below). |
| `source_system` | string | `legacy_v1` (through Jun-2025) \| `core_v2` (from Jul-2025). |
| `payment_method` | string | `PSE` \| `CARD` \| `CASH` \| `TRANSFER`. |
| `status` | string | `SETTLED` \| `REVERSED`. |
| `reversed_payment_id` | bigint | Only on `REVERSED` rows: the payment being voided. |

Payment semantics:

- **`legacy_v1` reports amounts in the currency's minor unit** and uses its own loan reference
  format. `core_v2` reports in major units and uses the identifier directly.
- A row with `status = 'REVERSED'` **voids** the payment named in `reversed_payment_id`: neither
  the voided payment nor the reversal row constitutes money received. A customer whose payment was
  reversed usually pays again shortly after, and *that* one is an effective payment.

---

## `raw_customers.csv` — customer master

Every origination record creates a `customer_id`. **A person's legal identity is their
`document_number`**: the same person may hold more than one `customer_id`.

| Column | Type | Notes |
|---|---|---|
| `customer_id` | bigint | Technical key from the source system. |
| `document_number` | string | National ID number. |
| `country` | string | `CO` \| `BR`. |
| `city` | string | Free text typed at the point of sale. |
| `email` | string | Free text. |
| `birth_year` | int | |
| `monthly_income` | string | Self-declared income, unvalidated at the source. |
| `created_at` | string | Record creation. |
| `_ingested_at` | string | |

---

## `raw_merchants_history.csv` — merchant history

An **append-only** table: each change to a merchant's attributes appends a row with the date from
which it applies. There is no end date and no current-version flag.

| Column | Type | Notes |
|---|---|---|
| `merchant_id` | bigint | |
| `merchant_name` | string | Trade name; changes in a non-normalized way. |
| `category` | string | The merchant's category during that period. |
| `country` | string | `CO` \| `BR`. |
| `valid_from` | date | Date from which these attributes apply. |

> A merchant's category can change over time. A historical report uses the category
> **in effect on the date of the event**.

---

## `raw_fx_rates.csv` — FX rates

Published by the official provider. **The provider only publishes on business days.**

| Column | Type | Notes |
|---|---|---|
| `rate_date` | date | |
| `currency` | string | `COP` \| `BRL`. |
| `units_per_usd` | decimal | Units of local currency per 1 USD. |
