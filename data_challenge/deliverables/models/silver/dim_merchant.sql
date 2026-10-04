-- Type the merchant history and keep missing categories visible as UNKNOWN.
with base as (
  select
    cast(merchant_id as bigint) as merchant_id,
    trim(merchant_name) as merchant_name,
    coalesce(nullif(trim(category), ''), 'UNKNOWN') as category,
    trim(country) as country,
    cast(valid_from as date) as valid_from
  from {{ source('raw', 'raw_merchants_history') }}
),

-- Use the next version's start date as the current version's end date.
scd as (
  select
    *,
    lead(valid_from) over (partition by merchant_id order by valid_from) as valid_to
  from base
)

-- Publish the SCD2 history and flag the latest version.
select
  merchant_id,
  merchant_name,
  category,
  country,
  valid_from,
  valid_to,
  valid_to is null as is_current
from scd
