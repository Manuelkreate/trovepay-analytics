with month_ends as (
    select distinct
        last_day(transaction_timestamp) as observation_date
    from {{ ref('stg_transactions') }}
),

merchants as (
    select
        merchant_id,
        onboarding_date
    from {{ ref('stg_merchants') }}
),

merchant_observations as (
    select
        m.merchant_id,
        me.observation_date
    from merchants m
    cross join month_ends me
    where me.observation_date >= m.onboarding_date
      and me.observation_date <= current_date
)

select * from merchant_observations