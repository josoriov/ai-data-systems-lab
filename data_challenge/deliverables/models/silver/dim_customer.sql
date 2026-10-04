-- Clean customer attributes and count the technical IDs held by each person.
with base as (
  select
    trim(document_number) as document_number,
    cast(customer_id as bigint) as customer_id,
    trim(country) as country,
    nullif(trim(city), '') as city,
    nullif(lower(trim(email)), '') as email,
    try_cast(birth_year as integer) as birth_year,
    try_cast(replace(trim(monthly_income), ',', '') as decimal(18,2)) as monthly_income,
    {{ parse_ts_utc('created_at') }} as created_at_utc,
    count(distinct cast(customer_id as bigint)) over (
      partition by trim(document_number)
    ) as customer_id_count
  from {{ source('raw', 'raw_customers') }}
),

-- Rank duplicate customer records so the latest version wins.
ranked as (
  select
    *,
    row_number() over (
      partition by document_number
      order by created_at_utc desc nulls last, customer_id desc
    ) as rn
  from base
)

-- Publish one representative record per legal document.
select
  document_number,
  country,
  city,
  email,
  birth_year,
  monthly_income,
  created_at_utc,
  customer_id_count
from ranked
where rn = 1
