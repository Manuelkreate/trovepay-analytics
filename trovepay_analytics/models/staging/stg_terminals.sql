with source as (
    select * from {{source('trovepay_raw',  'raw_terminals')}}
),

clean as (
    select
        cast(terminal_id as varchar) as terminal_id,
        cast(merchant_id as varchar) as merchant_id,
        cast(assigned_at as date) as assigned_at,
        cast(deactivated_at as date) as deactivated_at
    from source
)

select * from clean