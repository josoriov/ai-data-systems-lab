-- Report loan count and GMV for the January 2026 disbursement cohort.
select
  date '2026-01-01' as month,
  count(*) as n_loans,
  cast(sum(principal_usd order by loan_id) as decimal(18,2)) as gmv_usd
from {{ ref('fct_loan') }}
where date_trunc('month', disbursement_date) = date '2026-01-01'
