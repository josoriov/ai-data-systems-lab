-- Publish installment status only for the requested final cutoff.
select
  loan_id,
  installment_number,
  due_date,
  amount_due,
  paid_amount,
  remaining_amount,
  settlement_at_utc,
  {{ bogota_date('settlement_at_utc') }} as settlement_date,
  days_past_due
from {{ ref('int_installment_status') }}
where cutoff_date = cast('{{ var("cutoff_date") }}' as date)
