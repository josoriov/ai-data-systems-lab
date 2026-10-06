# AI usage log

## Delegation and responsibility

I used agents to profile the raw CSVs, draft repetitive SQL after I had set the
rules, scaffold tests, and review intermediate output. I decided the business
definitions, model grains, scope, and whether each figure in `RESULTS.md`
reconciled with the source data and model outputs.

Delegated to the agents:

- Data profiling: column formats, duplicate rates, sentinel values, the mixed
  timestamp encodings, and value distributions across the seven extracts.
- First drafts of repetitive SQL (casting, deduplication, FX lookups) once I
  specified the rule each model had to implement.
- Test scaffolding and an adversarial review pass over the models.

Kept under my control:

- Validity rules: deleted CDC applications, orphaned migration loans, the
  sentinel `customer_id` 999999999, and reversal semantics.
- Temporal definitions: FIFO allocation, DPD, FPD30 eligibility, PAR30, and
  "category at the date of the event".
- Scope: trimming the first draft down to the required models.
- Final verification of every number against the built models and the exported
  CSVs.

The first agent pass over-built the project: optional outputs, a model per CTE,
and nine Python scripts. I cut it back to the six required Silver models, the
two Gold models, the two intermediates whose logic is genuinely reused, and
three orchestration scripts. No answer total changed. A later pass removed more:
the FIFO model was rewritten around two cumulative scales instead of a
row-by-row allocation, the three scripts became one, and money moved to
decimals. Again, no published figure changed.

## Decisive prompts

These are the prompts that changed the shape of the solution, not the routine
ones. In each case I stated the rule, the agent drafted, and I checked the
result against the source data and the built models.

1. "The CDC feed is append-only, and `_op='D'` means the source deleted that
   application. Before you write any model, let me see the row counts broken
   down by `_op` and `status`, and how many applications have a known
   `customer_id` somewhere in their history." — forced evidence before
   modelling and surfaced the sentinel `999999999` applications.
2. "Don't allocate payments one row at a time. Give each installment and each
   payment a cumulative range, then define FIFO as the overlap between those
   ranges, and show me the total allocated per loan never goes above the money
   received." — turned a procedural allocation into one set-based model and
   produced the `assert_fifo_conservation` test. In the final pass I made the
   same idea simpler to read: an installment is paid up to the overlap of its
   own due range with the loan's total paid amount.
3. "A reversal has to be dated by the reversal timestamp, not by the cancelled
   payment's timestamp, and only within the same source system. Pull up a June
   payment that got reversed in July and tell me what June's balance should
   look like." — fixed the point-in-time rule in `int_payment_history`: a
   payment stays effective until it is actually reversed.
4. "For merchant reporting, I want you to join the SCD2 version whose
   `[valid_from, valid_to)` interval contains each event date. Do this separately for
   applications, disbursements, and portfolio snapshots. Don't ever use the
   current category." — produced the dated joins in `agg_merchant_monthly`. I
   confirmed the `dim_merchant` intervals partition the calendar with no overlaps
   and spot-checked a merchant whose category changed mid-history (1004: FASHION
   → HOME on 2025-09-04).

## Cases where AI output was wrong

1. An early timestamp profile let DuckDB's session timezone affect SQL-style
   timestamps and epoch values. It reported too many post-cutoff events and
   false payment conflicts. I caught it by comparing the same UTC instants
   written in all three source formats. `parse_ts_utc` now declares UTC
   explicitly before conversion to Bogotá dates.
2. An early FX query reused an unqualified `currency` name inside a correlated
   lookup, so it could compare the FX column to itself and pick the wrong
   rate. Per-loan COP/BRL spot checks exposed it; the macro now receives an
   explicitly qualified outer expression.
3. The first Gold models summed USD as floating point. Two consecutive runs
   produced the last decimals differently, and a comparison of
   `agg_merchant_monthly` from two builds showed `1e-10`-level differences in
   `outstanding_usd`. Money should not move between runs. I cast every money
   division to `decimal`, rounded the Gold money columns to cents, and re-ran
   twice to confirm the CSVs are now byte-for-byte stable. This was the most
   valuable catch: it is invisible in any single run.
4. The agent read a merchant with a positive portfolio and no delinquent loans
   as an undefined rate and emitted null. That misreads the definition: no
   delinquent balance is a **0% rate**, not an unknown — only a zero portfolio
   is genuinely undefined. Component reconciliation caught the mismatch; the
   numerator now uses zero while a zero denominator still returns a null rate.

## Final verification

- I ran the exact command from `README.md` from scratch: seven raw
  tables loaded, 10 dbt models built, and all 49 data tests passed.
- The two singular business tests prove that every reversal resolves and that
  FIFO preserves total money without paying a later installment first.
- I materialized the old and rewritten FIFO results side by side and compared
  both directions with `except all` on the declared grain and every measure:
  1,230,323 rows, zero differences.
- The main counts also reconcile without the answer queries: 28,075 distinct
  raw loans minus 120 invalid migration loans gives 27,955 valid loans, and
  30,000 customer IDs minus 29,093 people gives 907 redundant IDs.
- Summing the loan snapshot gives USD 2,057,606.87 outstanding and USD
  423,221.11 over 30 DPD, the same components used for the reported PAR30.
- I kept a copy of the first set of outputs, ran the full pipeline again, and
  compared each CSV with `diff -q`; no file changed.
