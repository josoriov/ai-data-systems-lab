{% macro parse_ts_utc(column) %}
-- The extracts mix epoch milliseconds, SQL timestamps and ISO timestamps.
-- Any of them represents the same UTC instant, so normalize before comparing.
case
  when {{ column }} is null or trim(cast({{ column }} as varchar)) = '' then null
  when regexp_matches(trim(cast({{ column }} as varchar)), '^-?[0-9]+$')
    then timezone('UTC', epoch_ms(cast(trim(cast({{ column }} as varchar)) as bigint)))
  when regexp_matches(trim(cast({{ column }} as varchar)), '^[0-9]{4}-[0-9]{2}-[0-9]{2} ')
    then timezone('UTC', try_cast(trim(cast({{ column }} as varchar)) as timestamp))
  else try_cast(trim(cast({{ column }} as varchar)) as timestamptz)
end
{% endmacro %}

{% macro bogota_date(ts_expr) %}
-- Local operating date for a UTC instant; analytics reports on business days.
cast(timezone('America/Bogota', {{ ts_expr }}) as date)
{% endmacro %}

{% macro fx_rate_asof(currency_expr, date_expr) %}
(
  -- Latest published rate on or before the date; the provider skips weekends.
  select cast(f.units_per_usd as decimal(18,6))
  from {{ source('raw', 'raw_fx_rates') }} f
  where trim(f.currency) = {{ currency_expr }}
    and cast(f.rate_date as date) <= {{ date_expr }}
  order by cast(f.rate_date as date) desc
  limit 1
)
{% endmacro %}
