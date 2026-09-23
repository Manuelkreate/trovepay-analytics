with source as (
    select * from {{source('trovepay_raw', 'raw_transactions')}}
),

clean as (
    select
        cast(transaction_id as varchar) as transaction_id,
        cast(merchant_id as varchar) as merchant_id,
        cast(terminal_id as varchar) as terminal_id,
        cast(timestamp as timestamp) as transaction_timestamp,
        cast(amount as decimal(18,2)) as amount,
        cast(status as varchar) as status,
        cast(reversed_at as timestamp) as reversed_at
    from source
)

select * from clean