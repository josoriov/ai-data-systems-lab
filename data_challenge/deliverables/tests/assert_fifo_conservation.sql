-- FIFO must preserve money and cannot pay a later installment first.
-- Add each installment's earlier unpaid balance so ordering can be checked.
with status as (
  select
    *,
    coalesce(sum(remaining_amount) over (
      partition by cutoff_date, loan_id
      order by installment_number
      rows between unbounded preceding and 1 preceding
    ), 0) as earlier_remaining
  from {{ ref('int_installment_status') }}
),

-- Catch negative balances, lost money, and payments applied out of order.
bad_rows as (
  select cutoff_date, loan_id
  from status
  where paid_amount < 0
     or remaining_amount < 0
     or abs(paid_amount + remaining_amount - amount_due) > 0.005
     or (paid_amount > 0 and earlier_remaining > 0.005)
),

-- Reuse the exact set of month-ends produced by the model under test.
cutoffs as (
  select distinct cutoff_date from status
),

-- Sum the payments that should be effective at each cutoff.
payment_totals as (
  select c.cutoff_date, p.loan_id, sum(p.amount) as amount
  from cutoffs c
  join {{ ref('int_payment_history') }} p
    on {{ bogota_date('p.paid_at_utc') }} <= c.cutoff_date
   and (p.reversed_at_utc is null
        or {{ bogota_date('p.reversed_at_utc') }} > c.cutoff_date)
  join {{ ref('fct_loan') }} l using (loan_id)
  group by c.cutoff_date, p.loan_id
),

-- Sum scheduled and allocated amounts for each loan and cutoff.
status_totals as (
  select
    cutoff_date,
    loan_id,
    sum(amount_due) as due,
    sum(paid_amount) as paid
  from status
  group by cutoff_date, loan_id
)

-- A dbt singular test passes only when this query returns no rows.
select cutoff_date, loan_id from bad_rows
union all
select s.cutoff_date, s.loan_id
from status_totals s
left join payment_totals p using (cutoff_date, loan_id)
where abs(s.paid - least(s.due, coalesce(p.amount, 0))) > 0.005
