with latest as (
    select max(observation_date) as observation_date
    from {{ ref('int_credit_readiness') }}
)

select
    r.merchant_id,
    m.business_name,
    m.onboarding_date,
    r.observation_date,
    r.qualifying_txn_count_90d,
    r.qualifying_txn_value_90d,
    r.days_since_last_activity,
    r.rolling_ready_state,
    r.first_ready_date,
    case
        when r.rolling_ready_state then 'ready'
        when r.qualifying_txn_count_90d = 0 then 'inactive_90d'
        else 'active_not_ready'
    end as readiness_status
from {{ ref('int_credit_readiness') }} r
inner join latest using (observation_date)
inner join {{ ref('stg_merchants') }} m using (merchant_id)