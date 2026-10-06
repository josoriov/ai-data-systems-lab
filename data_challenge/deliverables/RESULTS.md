# Business results

These figures describe the synthetic Lumo lending dataset.

Every figure below comes from a query in `analyses/` and is also exported to
`outputs/` by `scripts/run_data_challenge.py`.

| # | Answer | Query |
| --- | --- | --- |
| 1 | 59,059 valid applications; 33,007 approved; 55.89% approval rate | [`q1_applications_approval.sql`](analyses/q1_applications_approval.sql) |
| 2 | 27,955 valid loans; USD 8,780,942.16 GMV | [`q2_loans_gmv.sql`](analyses/q2_loans_gmv.sql) |
| 3 | January 2026: 1,540 loans; USD 473,272.15 GMV | [`q3_january_2026_cohort.sql`](analyses/q3_january_2026_cohort.sql) |
| 4 | Global FPD30: 8.88% (2,204 / 24,821); January 2026: 7.79% (120 / 1,540) | [`q4_fpd30.sql`](analyses/q4_fpd30.sql) |
| 5 | USD 2,057,606.87 outstanding; USD 423,221.11 at DPD > 30; PAR30 20.57% | [`q5_par30_balance.sql`](analyses/q5_par30_balance.sql) |
| 6 | Top five merchants hold 39.63% of GMV | [`q6_merchant_concentration.sql`](analyses/q6_merchant_concentration.sql) |
| 7 | 29,093 real people and 907 redundant customer IDs | [`q7_customers_redundant_ids.sql`](analyses/q7_customers_redundant_ids.sql) |

## Merchant concentration

| Rank | Merchant | GMV USD | Share | Cumulative share |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1607 | 2,062,698.44 | 23.49% | 23.49% |
| 2 | 1397 | 683,302.34 | 7.78% | 31.27% |
| 3 | 1664 | 379,017.69 | 4.32% | 35.59% |
| 4 | 1030 | 206,931.64 | 2.36% | 37.95% |
| 5 | 1286 | 148,238.13 | 1.69% | 39.63% |

Merchant 1607 alone represents almost a quarter of GMV, and the top five hold
almost 40%. That concentration means one merchant's approval or delinquency
behaviour can move the portfolio-wide rates, so leaders should read the global
figures next to the merchant-level breakdown rather than in isolation.

## How the numbers were checked

`dbt build` runs 49 tests over the grains, relationships, accepted values, rate
ranges, reversal integrity, and FIFO conservation. I also checked three simple
reconciliations outside the answer queries:

- 28,075 distinct raw loans minus 120 invalid migration loans gives 27,955
  valid loans;
- 30,000 customer IDs minus 29,093 people gives 907 redundant IDs; and
- the loan snapshot sums to USD 2,057,606.87 outstanding, including USD
  423,221.11 over 30 DPD.

The answer queries match the exported CSVs. USD totals are stored and summed as
decimals, so repeated runs return the same cents.
