with source as (
    select * from {{source('trovepay_raw', 'raw_loans')}}
),

clean as (
    select
        cast(loan_id as varchar) as loan_id,
        cast(application_id as varchar) as application_id,
        cast(merchant_id as varchar) as merchant_id,
        cast(disbursement_date as timestamp) as disbursement_date,
        cast(loan_amount as decimal(18,2)) as loan_amount,
        cast(tenure_months as smallint) as tenure_months,
        cast(maturity_date as timestamp) as maturity_date
    from source
)

select * from clean