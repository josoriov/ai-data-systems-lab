-- One row per live application in its final CDC state.
--
-- The CDC feed appends a row on every state change, so we keep the latest
-- event per application (source time first, ingestion time as tie-breaker) and
-- drop applications whose last operation is a delete. Some applications carry
-- the sentinel customer_id 999999999: when the same history shows the real ID
-- in the customer master, we swap it in; otherwise it stays null.

with events as (
    select distinct
        cast(application_id as bigint) as application_id,
        cast(customer_id as bigint) as customer_id,
        cast(merchant_id as bigint) as merchant_id,
        try_cast(trim(requested_amount) as decimal(18,2)) as requested_amount,
        trim(currency) as currency,
        trim(status) as status,
        try_cast(nullif(trim(approved_amount), '') as decimal(18,2)) as approved_amount,
        {{ parse_ts_utc('event_at_utc') }} as event_at_utc,
        trim(_op) as _op,
        {{ parse_ts_utc('_ingested_at_utc') }} as _ingested_at_utc
    from {{ source('raw', 'raw_applications_cdc') }}
),

-- The one real customer ID that appears anywhere in an application's history.
-- The extract has at most one per application, so min() just picks it.
known_ids as (
    select e.application_id, min(cast(c.customer_id as bigint)) as known_customer_id
    from events e
    join {{ source('raw', 'raw_customers') }} c
        on cast(c.customer_id as bigint) = e.customer_id
    group by e.application_id
),

-- Replace the sentinel and rank events to find each application's final state.
final_events as (
    select
        e.application_id,
        case
            when e.customer_id = 999999999 then k.known_customer_id
            else e.customer_id
        end as customer_id,
        e.merchant_id,
        e.currency,
        e.requested_amount,
        e.approved_amount,
        e.status,
        e.event_at_utc,
        e._op,
        e._ingested_at_utc,
        min(e.event_at_utc) over (partition by e.application_id) as created_at_utc,
        row_number() over (
            partition by e.application_id
            order by e.event_at_utc desc, e._ingested_at_utc desc
        ) as rn
    from events e
    left join known_ids k using (application_id)
)

select
    application_id,
    customer_id,
    merchant_id,
    currency,
    requested_amount,
    approved_amount,
    status,
    created_at_utc,
    event_at_utc as last_event_at_utc,
    _ingested_at_utc as last_ingested_at_utc
from final_events
where rn = 1 and _op <> 'D'
