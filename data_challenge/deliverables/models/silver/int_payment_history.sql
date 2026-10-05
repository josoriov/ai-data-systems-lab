-- Normalize loan references, timestamps, and minor-unit legacy amounts.
with events as (
  select distinct
    cast(trim(payment_id) as bigint) as payment_id,
    trim(source_system) as source_system,
    case when trim(source_system) = 'legacy_v1'
      then cast(replace(trim(loan_ref), 'LN-', '') as bigint)
      else cast(trim(loan_ref) as bigint)
    end as loan_id,
    {{ parse_ts_utc('paid_at_utc') }} as paid_at_utc,
    cast(case when trim(source_system) = 'legacy_v1'
      then cast(amount_raw as decimal(20,0)) / 100
      else cast(amount_raw as decimal(18,2))
    end as decimal(18,2)) as amount,
    trim(payment_method) as payment_method,
    trim(status) as status,
    try_cast(nullif(trim(reversed_payment_id), '') as bigint) as reversed_payment_id
  from {{ source('raw', 'raw_payments') }}
),

-- Attach each reversal time to the payment it cancels.
reversals as (
  select
    source_system,
    reversed_payment_id as payment_id,
    min(paid_at_utc) as reversed_at_utc
  from events
  where status = 'REVERSED'
  group by source_system, reversed_payment_id
)

-- Keep one settled payment row and retain its reversal timestamp for snapshots.
select
  p.source_system,
  p.payment_id,
  p.loan_id,
  p.paid_at_utc,
  p.amount,
  p.payment_method,
  r.reversed_at_utc
from events p
left join reversals r using (source_system, payment_id)
where p.status = 'SETTLED'
