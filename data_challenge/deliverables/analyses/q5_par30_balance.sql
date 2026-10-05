-- Sum the final snapshot balance and the portion held by loans over 30 DPD.
select
  cast(sum(balance_usd) as decimal(18,2)) as outstanding_usd,
  cast(sum(case when dpd > 30 then balance_usd else 0 end) as decimal(18,2))
    as outstanding_dpd_gt_30_usd,
  sum(case when dpd > 30 then balance_usd else 0 end)::double
    / nullif(sum(balance_usd), 0) as par30_rate
from {{ ref('dm_loan_delinquency_snapshot') }}
