-- Count valid final-state applications and calculate the overall approval rate.
select
  count(*) as n_applications,
  count(*) filter (where status = 'APPROVED') as n_approved,
  count(*) filter (where status = 'APPROVED')::double / nullif(count(*), 0) as approval_rate
from {{ ref('fct_application') }}
