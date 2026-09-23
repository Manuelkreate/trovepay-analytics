with source as (
    select * from {{source('trovepay_raw', 'raw_repayment_schedule')}}
),

clean as (
    select
        cast(schedule_id as varchar) as schedule_id,
        cast(loan_id as varchar) as loan_id,
        cast(installment_number as smallint) as installment_number,
        cast(due_date as timestamp) as due_date,
        cast(amount_due as decimal(18,2)) as amount_due
    from source
)

select * from clean