-- Sum lifetime GMV for each merchant.
with by_merchant as (
  select merchant_id, sum(principal_usd order by loan_id) as gmv_usd
  from {{ ref('fct_loan') }}
  group by merchant_id
),

-- Calculate total GMV once so every merchant uses the same denominator.
total as (
  select sum(gmv_usd order by merchant_id) as gmv_usd
  from by_merchant
),

-- Calculate each merchant's share and rank by GMV.
ranked as (
  select
    b.merchant_id,
    b.gmv_usd,
    b.gmv_usd / t.gmv_usd as gmv_share,
    row_number() over (order by b.gmv_usd desc, b.merchant_id) as gmv_rank
  from by_merchant b
  cross join total t
)

-- Return the top five merchants and their cumulative share.
select
  merchant_id,
  cast(gmv_usd as decimal(18,2)) as gmv_usd,
  gmv_share,
  gmv_rank,
  sum(gmv_share) over (order by gmv_rank) as cumulative_share
from ranked
where gmv_rank <= 5
order by gmv_rank
