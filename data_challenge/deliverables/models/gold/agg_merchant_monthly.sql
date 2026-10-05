-- Count applications by their Bogotá creation month.
with applications as (
  select
    a.merchant_id,
    date_trunc('month', {{ bogota_date('a.created_at_utc') }})::date as month,
    count(*) as n_applications,
    count(*) filter (where a.status = 'APPROVED') as n_approved
  from {{ ref('fct_application') }} a
  -- Match the merchant version active on the application date.
  join {{ ref('dim_merchant') }} m
    on m.merchant_id = a.merchant_id
   and m.valid_from <= {{ bogota_date('a.created_at_utc') }}
   and (m.valid_to is null or {{ bogota_date('a.created_at_utc') }} < m.valid_to)
  group by a.merchant_id, month
),

-- Count disbursed loans and their USD principal by cohort month.
loans as (
  select
    l.merchant_id,
    date_trunc('month', l.disbursement_date)::date as month,
    count(*) as n_loans,
    -- GMV is money, so keep it at cents.
    round(sum(l.principal_usd order by l.loan_id), 2) as gmv_usd
  from {{ ref('fct_loan') }} l
  -- Match category per loan before rolling up to the required grain.
  join {{ ref('dim_merchant') }} m
    on m.merchant_id = l.merchant_id
   and m.valid_from <= l.disbursement_date
   and (m.valid_to is null or l.disbursement_date < m.valid_to)
  group by l.merchant_id, month
),

-- Evaluate first-payment defaults at the fixed reporting cutoff.
fpd30 as (
  select
    l.merchant_id,
    date_trunc('month', l.disbursement_date)::date as month,
    count(*) filter (
      where datediff('day', s.due_date, cast('{{ var("cutoff_date") }}' as date)) >= 30
    ) as fpd30_eligible,
    count(*) filter (
      where (s.remaining_amount > 0
             and datediff('day', s.due_date, cast('{{ var("cutoff_date") }}' as date)) > 30)
         or (s.remaining_amount = 0
             and datediff('day', s.due_date, s.settlement_date) > 30)
    ) as fpd30_default
  from {{ ref('fct_installment_status') }} s
  join {{ ref('fct_loan') }} l using (loan_id)
  join {{ ref('dim_merchant') }} m
    on m.merchant_id = l.merchant_id
   and m.valid_from <= l.disbursement_date
   and (m.valid_to is null or l.disbursement_date < m.valid_to)
  where s.installment_number = 1
  group by l.merchant_id, month
),

-- Roll installment balances up to one row per loan and month-end.
portfolio as (
  select
    cutoff_date,
    loan_id,
    sum(remaining_amount) as balance_local,
    coalesce(max(days_past_due) filter (where remaining_amount > 0), 0) as dpd
  from {{ ref('int_installment_status') }}
  group by cutoff_date, loan_id
),

-- Convert each loan balance to USD once, using decimal maths.
portfolio_usd as (
  select
    l.merchant_id,
    date_trunc('month', p.cutoff_date)::date as month,
    cast(p.balance_local / {{ fx_rate_asof('l.currency', 'p.cutoff_date') }} as decimal(18,6)) as balance_usd,
    p.dpd
  from portfolio p
  join {{ ref('fct_loan') }} l using (loan_id)
  -- PAR uses the category active on the snapshot date.
  join {{ ref('dim_merchant') }} m
    on m.merchant_id = l.merchant_id
   and m.valid_from <= p.cutoff_date
   and (m.valid_to is null or p.cutoff_date < m.valid_to)
),

-- Sum the USD balances and split out the portion over 30 DPD.
par30 as (
  select
    merchant_id,
    month,
    round(sum(balance_usd), 2) as outstanding_usd,
    round(sum(balance_usd) filter (where dpd > 30), 2) as outstanding_dpd_gt_30_usd
  from portfolio_usd
  group by merchant_id, month
),

-- Keep every merchant-month that appears in any metric.
keys as (
  select merchant_id, month from applications
  union select merchant_id, month from loans
  union select merchant_id, month from fpd30
  union select merchant_id, month from par30
)

-- Join the four metric groups at the required merchant-month grain.
select
  k.merchant_id,
  k.month,
  coalesce(a.n_applications, 0) as n_applications,
  coalesce(a.n_approved, 0) as n_approved,
  a.n_approved::double / nullif(a.n_applications, 0) as approval_rate,
  coalesce(l.n_loans, 0) as n_loans,
  coalesce(l.gmv_usd, 0) as gmv_usd,
  coalesce(f.fpd30_eligible, 0) as fpd30_eligible,
  coalesce(f.fpd30_default, 0) as fpd30_default,
  f.fpd30_default::double / nullif(f.fpd30_eligible, 0) as fpd30_rate,
  coalesce(p.outstanding_usd, 0) as outstanding_usd,
  coalesce(p.outstanding_dpd_gt_30_usd, 0) as outstanding_dpd_gt_30_usd,
  coalesce(p.outstanding_dpd_gt_30_usd, 0)::double / nullif(p.outstanding_usd, 0) as par30_rate
from keys k
left join applications a using (merchant_id, month)
left join loans l using (merchant_id, month)
left join fpd30 f using (merchant_id, month)
left join par30 p using (merchant_id, month)
