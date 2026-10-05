-- Roll the final installment status up to one balance and DPD per loan.
with balances as (
  select
    loan_id,
    sum(remaining_amount) as balance_local,
    coalesce(max(days_past_due) filter (where remaining_amount > 0), 0) as dpd
  from {{ ref('fct_installment_status') }}
  group by loan_id
)

-- Add loan details, convert the balance to USD, and assign the DPD bucket.
select
  b.loan_id,
  l.customer_id,
  l.merchant_id,
  l.currency,
  l.disbursement_date,
  b.balance_local,
  cast(
    b.balance_local / {{ fx_rate_asof('l.currency', "cast('" ~ var('cutoff_date') ~ "' as date)") }}
    as decimal(18,2)
  ) as balance_usd,
  b.dpd,
  case
    when b.dpd = 0 then '0'
    when b.dpd <= 30 then '1-30'
    when b.dpd <= 60 then '31-60'
    when b.dpd <= 90 then '61-90'
    else '90+'
  end as dpd_bucket
from balances b
join {{ ref('fct_loan') }} l using (loan_id)
