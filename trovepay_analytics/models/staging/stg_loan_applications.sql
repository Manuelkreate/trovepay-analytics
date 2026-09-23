with source as (
    select * from {{source('trovepay_raw', 'raw_loan_applications')}}
),

clean as (
    select
        cast(application_id as varchar) as application_id,
        cast(merchant_id as varchar) as merchant_id,
        cast(application_date as timestamp) as application_date,
        cast(decision as varchar) as decision,
        cast(rejection_reason as varchar) as rejection_reason
    from source
)

select * from clean