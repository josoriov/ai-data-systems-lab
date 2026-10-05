-- Every reversal must point to one settled payment in the same source system.
-- Normalize the fields needed to compare settled payments with reversals.
with events as (
  select distinct
    trim(source_system) as source_system,
    cast(trim(payment_id) as bigint) as payment_id,
    trim(status) as status,
    try_cast(nullif(trim(reversed_payment_id), '') as bigint) as reversed_payment_id
  from {{ source('raw', 'raw_payments') }}
),

-- List the payment keys that can be reversed.
settled as (
  select source_system, payment_id
  from events
  where status = 'SETTLED'
),

-- List each reversal under the key of its target payment.
reversals as (
  select source_system, reversed_payment_id as payment_id
  from events
  where status = 'REVERSED'
)

-- Fail when a reversal has no unique settled target or a payment is reversed twice.
select r.source_system, r.payment_id
from reversals r
left join settled s using (source_system, payment_id)
group by r.source_system, r.payment_id
having count(s.payment_id) <> 1 or count(*) > 1
