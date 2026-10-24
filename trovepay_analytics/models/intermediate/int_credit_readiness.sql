with reference_thresholds as (
    select
        quantile_cont(qualifying_txn_count_90d, 0.5) as min_txn_count_90d,
        quantile_cont(qualifying_txn_value_90d, 0.5) as min_txn_value_90d
    from {{ ref('int_qualifying_activity') }}
    where observation_date = date '2025-06-30'
        and qualifying_txn_count_90d > 0
),

readiness_flagged as (
    select
        a.merchant_id,
        a.observation_date,
        a.qualifying_txn_count_90d,
        a.qualifying_txn_value_90d,
        r.days_since_last_activity,
        (
            a.qualifying_txn_count_90d >= t.min_txn_count_90d
            and a.qualifying_txn_value_90d >= t.min_txn_value_90d
            and coalesce(r.days_since_last_activity <= 45, FALSE)
        ) as rolling_ready_state
    from {{ ref('int_qualifying_activity') }} a
    cross join reference_thresholds t
    left join {{ ref('int_merchant_recency') }} r
        on a.merchant_id = r.merchant_id
        and a.observation_date = r.observation_date
)

select
    merchant_id,
    observation_date,
    qualifying_txn_count_90d,
    qualifying_txn_value_90d,
    days_since_last_activity,
    rolling_ready_state,
    min(observation_date) filter (where rolling_ready_state)
        over (partition by merchant_id)
        as first_ready_date
from readiness_flagged