-- Compare real people with the number of technical customer IDs they hold.
select
  count(*) as n_persons,
  sum(customer_id_count) as n_customer_ids,
  sum(customer_id_count) - count(*) as n_redundant_ids
from {{ ref('dim_customer') }}
