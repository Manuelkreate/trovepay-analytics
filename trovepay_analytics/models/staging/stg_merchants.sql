with source as (
    select * from {{source('trovepay_raw', 'raw_merchants')}}
),

clean as (
    select
        cast(merchant_id as varchar) as merchant_id,
        cast(business_name as varchar) as business_name,
        cast(business_type as varchar) as business_type,
        cast(category as varchar) as category,
        cast(state as varchar) as state,
        cast(lga as varchar) as lga,
        cast(business_start_date as date) as business_start_date,
        cast(onboarding_date as date) as onboarding_date,
        cast(cohort as varchar) as cohort
    from source
)

select * from clean