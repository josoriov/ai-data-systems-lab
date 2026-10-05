-- Count valid loans and sum disbursed principal in USD.
select
  count(*) as n_loans,
  cast(sum(principal_usd order by loan_id) as decimal(18,2)) as gmv_usd
from {{ ref('fct_loan') }}
