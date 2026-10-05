-- Evaluate FPD30 once per loan from its first installment.
with loans as (
  select
    date_trunc('month', l.disbursement_date)::date as cohort,
    datediff('day', s.due_date, cast('{{ var("cutoff_date") }}' as date)) >= 30 as eligible,
    (s.remaining_amount > 0
      and datediff('day', s.due_date, cast('{{ var("cutoff_date") }}' as date)) > 30)
    or (s.remaining_amount = 0
      and datediff('day', s.due_date, s.settlement_date) > 30) as defaulted
  from {{ ref('fct_installment_status') }} s
  join {{ ref('fct_loan') }} l using (loan_id)
  where s.installment_number = 1
),

-- Create the global and January 2026 populations requested in the question.
populations as (
  select 'global' as population, * from loans
  union all
  select '2026-01' as population, * from loans where cohort = date '2026-01-01'
)

-- Calculate each FPD30 rate from its numerator and eligible denominator.
select
  population,
  count(*) filter (where eligible) as fpd30_eligible,
  count(*) filter (where defaulted) as fpd30_default,
  count(*) filter (where defaulted)::double
    / nullif(count(*) filter (where eligible), 0) as fpd30_rate
from populations
group by population
order by case when population = 'global' then 0 else 1 end
