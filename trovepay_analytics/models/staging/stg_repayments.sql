with  source as (
    select * from {{source('trovepay_raw', 'raw_repayments')}}
),

clean as (
    select
        cast(repayment_id as varchar) as repayment_id,
        cast(loan_id as varchar) as loan_id,
        cast(repayment_date as timestamp) as repayment_date,
        cast(amount as decimal(18,2)) as amount
    from source
)

select * from clean