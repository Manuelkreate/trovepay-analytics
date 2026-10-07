with history as (
    select
        mo.merchant_id,
        mo.observation_date,
        max(d.activity_date) as last_qualifying_activity_date
    from {{ ref('int_merchant_observations') }} mo
    left join {{ ref('int_merchant_activity_daily') }} d
        on mo.merchant_id = d.merchant_id
        and d.activity_date <= mo.observation_date
    group by mo.merchant_id, mo.observation_date
)

select
    merchant_id,
    observation_date,
    last_qualifying_activity_date,
    date_diff('day', last_qualifying_activity_date, observation_date) as days_since_last_activity
from history
