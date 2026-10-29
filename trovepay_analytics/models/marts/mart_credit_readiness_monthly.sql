with base as (
    select
        merchant_id,
        observation_date,
        qualifying_txn_count_90d,
        rolling_ready_state,
        first_ready_date,
        lag(rolling_ready_state) over (
            partition by merchant_id
            order by observation_date
        ) as prev_ready_state
    from {{ ref('int_credit_readiness') }}
)

select
    observation_date,
    count(*) as merchants_onboarded,
    count(*) filter (where qualifying_txn_count_90d > 0) as active_merchants,
    count(*) filter (where rolling_ready_state) as ready_merchants,
    round(
        count(*) filter (where rolling_ready_state)
        / nullif(count(*) filter (where qualifying_txn_count_90d > 0), 0),
        4
    ) as ready_share_of_active,
    count(*) filter (
        where rolling_ready_state and not coalesce(prev_ready_state, false)
    ) as entered_ready,
    count(*) filter (
        where not rolling_ready_state and prev_ready_state
    ) as exited_ready,
    count(*) filter (where observation_date = first_ready_date) as first_time_ready
from base
group by observation_date