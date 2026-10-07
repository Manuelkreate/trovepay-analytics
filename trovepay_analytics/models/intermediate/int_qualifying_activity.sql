with base_windowed as (
    select
        mo.merchant_id,
        mo.observation_date,
        qt.transaction_id,
        qt.transaction_timestamp,
        qt.amount
    from {{ ref('int_merchant_observations') }} mo
    left join {{ ref('int_qualifying_transactions') }} qt
        on mo.merchant_id = qt.merchant_id
        and qt.transaction_timestamp <= mo.observation_date
        and qt.transaction_timestamp > mo.observation_date - interval '90 days'
        and (qt.reversed_at is null or qt.reversed_at > mo.observation_date)
),

rfm_metrics as (
    select
        merchant_id,
        observation_date,
        count(transaction_id) as qualifying_txn_count_90d,
        sum(amount) as qualifying_txn_value_90d,
        avg(amount) as avg_qualifying_txn_value_90d
    from base_windowed
    group by merchant_id, observation_date
),

monthly as (
    select
        merchant_id,
        observation_date,
        date_trunc('month', transaction_timestamp) as txn_month,
        count(transaction_id) as monthly_txn_count,
        sum(amount) as monthly_txn_value
    from base_windowed
    where transaction_id is not null
    group by merchant_id, observation_date, date_trunc('month', transaction_timestamp)
),

-- CV (coefficient of variation)
trend_cv_metrics as (
    select
        merchant_id,
        observation_date,
        stddev_pop(monthly_txn_value) / nullif(avg(monthly_txn_value), 0) as monthly_value_cv,
        regr_slope(monthly_txn_value, extract(epoch from txn_month)) as monthly_value_trend_slope
    from monthly
    group by merchant_id, observation_date
),

final as (
    select
        mo.merchant_id,
        mo.observation_date,
        coalesce(rm.qualifying_txn_count_90d, 0) as qualifying_txn_count_90d,
        coalesce(rm.qualifying_txn_value_90d, 0) as qualifying_txn_value_90d,
        rm.avg_qualifying_txn_value_90d,
        tc.monthly_value_cv,
        tc.monthly_value_trend_slope
    from {{ ref('int_merchant_observations') }} mo
    left join rfm_metrics rm
        on mo.merchant_id = rm.merchant_id
        and mo.observation_date = rm.observation_date
    left join trend_cv_metrics tc
        on mo.merchant_id = tc.merchant_id
        and mo.observation_date = tc.observation_date
)

select * from final