-- Type the raw loan extract and collapse duplicate dump rows.
with loans as (
  select distinct
    cast(loan_id as bigint) as loan_id,
    cast(application_id as bigint) as application_id,
    cast(merchant_id as bigint) as merchant_id,
    try_cast(trim(principal) as decimal(18,2)) as principal,
    trim(currency) as currency,
    try_cast(trim(term_months) as integer) as term_months,
    try_cast(trim(apr) as decimal(12,6)) as apr,
    {{ parse_ts_utc('disbursed_at_utc') }} as disbursed_at_utc,
    trim(status) as status
  from {{ source('raw', 'raw_loans') }}
),

-- Exclude loans without a valid approved application.
valid as (
  select
    l.*,
    a.customer_id,
    {{ bogota_date('l.disbursed_at_utc') }} as disbursement_date
  from loans l
  join {{ ref('fct_application') }} a
    on a.application_id = l.application_id
   and a.status = 'APPROVED'
),

-- Look up the FX rate in effect on each local disbursement date.
rated as (
  select
    v.*,
    {{ fx_rate_asof('v.currency', 'v.disbursement_date') }} as fx_units_per_usd
  from valid v
)

-- Publish valid loans with principal in both local currency and USD.
select
  loan_id,
  application_id,
  customer_id,
  merchant_id,
  principal,
  currency,
  term_months,
  apr,
  disbursed_at_utc,
  disbursement_date,
  status,
  fx_units_per_usd,
  -- Convert to USD with decimal maths: money must not pick up float rounding.
  cast(principal / fx_units_per_usd as decimal(18,6)) as principal_usd
from rated
