{{ config(materialized = 'table') }}

-- Installment status at every month-end, with payments applied FIFO.
--
-- Payments arrive at loan level, so we have to decide which installment each
-- payment covers. Instead of allocating payment by payment, we line up two
-- cumulative scales per loan: the amount due before each installment, and the
-- total paid so far. FIFO then means an installment is paid up to the overlap
-- between its due range [due_before, due_before + amount_due) and [0, total].
-- The payment whose cumulative total crosses the end of that range settles it.

with first_month as (
    select date_trunc('month', min(disbursement_date)) as month
    from {{ ref('fct_loan') }}
),

-- One cutoff per month-end, from the first disbursement through the report date.
cutoffs as (
    select last_day(month + n * interval '1 month') as cutoff_date
    from first_month,
         range(0, datediff('month', month, cast('{{ var("cutoff_date") }}' as date)) + 1) t(n)
),

-- Typed installment rows for valid loans only.
installments as (
    select distinct
        cast(i.loan_id as bigint) as loan_id,
        cast(i.installment_number as integer) as installment_number,
        cast(i.due_date as date) as due_date,
        cast(i.amount_due as decimal(18,2)) as amount_due
    from {{ source('raw', 'raw_installments') }} i
    join {{ ref('fct_loan') }} l on l.loan_id = cast(i.loan_id as bigint)
),

-- Amount already scheduled on the loan before each installment's own amount.
due_ranges as (
    select
        *,
        coalesce(sum(amount_due) over (
            partition by loan_id order by due_date, installment_number
            rows between unbounded preceding and 1 preceding
        ), 0) as due_before
    from installments
),

-- Payments still effective at each cutoff, with their running loan total.
-- A payment counts only while it has arrived and has not yet been reversed.
payments_at_cutoff as (
    select
        c.cutoff_date,
        p.loan_id,
        p.paid_at_utc,
        coalesce(sum(p.amount) over (
            partition by c.cutoff_date, p.loan_id
            order by p.paid_at_utc, p.source_system, p.payment_id
            rows between unbounded preceding and 1 preceding
        ), 0) as paid_before,
        sum(p.amount) over (
            partition by c.cutoff_date, p.loan_id
            order by p.paid_at_utc, p.source_system, p.payment_id
        ) as paid_after
    from cutoffs c
    join {{ ref('int_payment_history') }} p
        on {{ bogota_date('p.paid_at_utc') }} <= c.cutoff_date
       and (p.reversed_at_utc is null
            or {{ bogota_date('p.reversed_at_utc') }} > c.cutoff_date)
),

-- Total effective payment per loan and cutoff.
loan_paid as (
    select cutoff_date, loan_id, max(paid_after) as total_paid
    from payments_at_cutoff
    group by cutoff_date, loan_id
),

-- The single payment that completes each installment (its range covers due_end).
settled as (
    select
        p.cutoff_date,
        p.loan_id,
        i.installment_number,
        p.paid_at_utc as settlement_at_utc
    from payments_at_cutoff p
    join due_ranges i
        on i.loan_id = p.loan_id
       and p.paid_before < i.due_before + i.amount_due
       and p.paid_after >= i.due_before + i.amount_due
),

-- A loan only enters a snapshot after it has been disbursed.
loans_at_cutoff as (
    select c.cutoff_date, l.loan_id
    from {{ ref('fct_loan') }} l
    join cutoffs c on l.disbursement_date <= c.cutoff_date
),

-- Combine each installment with its paid balance and settlement per cutoff.
status as (
    select
        lc.cutoff_date,
        i.loan_id,
        i.installment_number,
        i.due_date,
        i.amount_due,
        least(i.amount_due, greatest(coalesce(lp.total_paid, 0) - i.due_before, 0)) as paid_amount,
        s.settlement_at_utc
    from loans_at_cutoff lc
    join due_ranges i using (loan_id)
    left join loan_paid lp
        on lp.cutoff_date = lc.cutoff_date and lp.loan_id = i.loan_id
    left join settled s
        on s.cutoff_date = lc.cutoff_date
       and s.loan_id = i.loan_id
       and s.installment_number = i.installment_number
)

-- Derive the remaining balance and DPD from the amount each installment paid.
select
    cutoff_date,
    loan_id,
    installment_number,
    due_date,
    amount_due,
    paid_amount,
    amount_due - paid_amount as remaining_amount,
    settlement_at_utc,
    case
        when due_date < cutoff_date and amount_due - paid_amount > 0
            then datediff('day', due_date, cutoff_date)
        else 0
    end as days_past_due
from status
