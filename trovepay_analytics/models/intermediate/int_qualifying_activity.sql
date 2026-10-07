with windowed_daily as (
    select
        mo.merchant_id,
        mo.observation_date,
        d.activity_date,
        d.daily_txn_count,
        d.daily_txn_value
    from {{ ref('int_merchant_observations') }} mo
    left join {{ ref('int_merchant_activity_daily') }} d
        on mo.merchant_id = d.merchant_id
        and d.activity_date <= mo.observation_date
        and d.activity_date > mo.observation_date - interval '90 days'
),

rfm_metrics as (
    select
        merchant_id,
        observation_date,
        sum(daily_txn_count) as qualifying_txn_count_90d,
        sum(daily_txn_value) as qualifying_txn_value_90d
    from windowed_daily
    group by merchant_id, observation_date
),

monthly as (
    select
        merchant_id,
        observation_date,
        date_trunc('month', activity_date) as activity_month,
        sum(daily_txn_count) as monthly_txn_count,
        sum(daily_txn_value) as monthly_txn_value
    from windowed_daily
    where activity_date is not null
    group by merchant_id, observation_date, date_trunc('month', activity_date)
),

trend_cv_metrics as (
    select
        merchant_id,
        observation_date,
        stddev_pop(monthly_txn_value) / nullif(avg(monthly_txn_value), 0) as monthly_value_cv,
        regr_slope(monthly_txn_value, extract(epoch from activity_month)) as monthly_value_trend_slope
    from monthly
    group by merchant_id, observation_date
)

select
    mo.merchant_id,
    mo.observation_date,
    coalesce(rm.qualifying_txn_count_90d, 0) as qualifying_txn_count_90d,
    coalesce(rm.qualifying_txn_value_90d, 0) as qualifying_txn_value_90d,
    rm.qualifying_txn_value_90d / nullif(rm.qualifying_txn_count_90d, 0) as avg_qualifying_txn_value_90d,
    tc.monthly_value_cv,
    tc.monthly_value_trend_slope
from {{ ref('int_merchant_observations') }} mo
left join rfm_metrics rm
    on mo.merchant_id = rm.merchant_id
    and mo.observation_date = rm.observation_date
left join trend_cv_metrics tc
    on mo.merchant_id = tc.merchant_id
    and mo.observation_date = tc.observation_date