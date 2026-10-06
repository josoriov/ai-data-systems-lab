# Assumptions and data-quality findings

These rules apply to the synthetic Lumo dataset and its reporting scenario.

1. The DuckDB `raw` schema is the Bronze layer. CSV values and duplicate rows
   are preserved there; typing and business rules start in Silver.

2. SQL, ISO-8601, and epoch-millisecond timestamps represent UTC instants.
   Business dates are derived in `America/Bogota`. Installment `due_date` is
   already a local date.

3. Portfolio, DPD, PAR30, and FPD30 use the fixed cutoff `2026-06-30`, supplied
   by `vars.cutoff_date`.

4. Applications use the latest CDC event, breaking timestamp ties with the
   ingestion timestamp. Applications whose final operation is `D` are removed.

5. Customer ID `999999999` is a sentinel. The extract carries at most one
   known ID per application, so it is resolved to the ID that appears in the
   customer master. Three rejected applications have no known ID and remain
   null.

6. A real customer is identified by `document_number`. When duplicate customer
   records disagree, attributes come from the latest `created_at`, then the
   greatest `customer_id` as a deterministic tie-breaker.

7. Merchant SCD2 intervals are `[valid_from, next valid_from)`. The last version
   is current. Missing categories remain visible as `UNKNOWN`.

8. A valid loan must reference an application whose final state is `APPROVED`.
   This removes 120 orphaned migration loans.

9. USD amounts use the latest published FX rate on or before the relevant date.
   GMV uses the disbursement date; balances use the snapshot date. A missing rate
   produces null rather than a future or invented rate. Money divisions are cast
   to decimal and Gold money columns are rounded to cents, so sums are exact and
   do not drift with float rounding.

10. `legacy_v1` loan references drop the `LN-` prefix and its minor-unit amounts
    are divided by 100. `core_v2` already uses loan IDs and major units.

11. A reversal targets a payment within the same source system. A payment is
    effective at a cutoff if it was received by then and had not yet been
    reversed. This keeps a June payment in June even if reversed in July.

12. FIFO orders installments by `(due_date, installment_number)` and payments by
    `(paid_at_utc, source_system, payment_id)`. The extra keys make timestamp ties
    deterministic. Payments above the scheduled balance remain unallocated.

13. Installment DPD is positive only while an installment has an unpaid balance.
    Loan DPD is the maximum DPD among its unpaid installments. Outstanding
    balance includes both overdue and future unpaid installments.

14. FPD30 includes loans whose first installment is at least 30 days past due at
    the cutoff. Default requires more than 30 days, whether still unpaid or paid
    late. A payment exactly 30 days late is not a default.

15. PAR30 is outstanding USD balance from loans with DPD greater than 30 divided
    by all outstanding USD balance.

16. In `agg_merchant_monthly`, applications use creation month, loans and FPD30
    use disbursement cohort month, and PAR30 uses snapshot month. Each event is
    matched to the merchant version active on its own date before aggregation.

17. Rates are calculated from summed numerators and denominators. A zero
    denominator returns null; rates are never averaged across rows.

## Findings applied in the models

- The application CDC contains 4,984 duplicate rows. Payment input contains
  1,537 exact duplicates and 666 payment keys whose timestamps use different
  formats for the same instant. Deduplication happens after timestamp parsing.
- There are 1,291 effective reversal targets, all resolved by source system.
- Sixteen merchant versions have no category and become `UNKNOWN`.
- Customer income is explicitly unvalidated: 1,505 values are `N/A` and 858
  parsed values are negative. `N/A` becomes null; negative values are retained
  rather than silently repaired.
- The customer master contains 30,000 technical IDs for 29,093 people.

## Scope deliberately deferred

- **Incremental materialization.** All models rebuild fully. At this data volume
  a full rebuild is simpler and keeps the FIFO and SCD2 logic obviously correct;
  I would add incremental strategies per model only once volume or run time
  requires them.
- **Late-arriving data.** The snapshot models rebuild from `raw` on every run,
  so a late row is picked up automatically and no watermark logic is needed
  here.
- **Contracts, exposures, and a dbt snapshot for the SCD2 dimension.** The
  append-only merchant history already yields the SCD2 intervals directly, and
  the project has a single consumer, so these add ceremony without value at this
  stage.
