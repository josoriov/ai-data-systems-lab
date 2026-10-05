-- Publish settled payments that were never reversed and belong to valid loans.
select
  p.source_system,
  p.payment_id,
  p.loan_id,
  l.customer_id,
  l.merchant_id,
  l.currency,
  p.paid_at_utc,
  {{ bogota_date('p.paid_at_utc') }} as paid_date,
  p.amount,
  p.payment_method
from {{ ref('int_payment_history') }} p
join {{ ref('fct_loan') }} l using (loan_id)
where p.reversed_at_utc is null
