with daily_activity as (
    select
        merchant_id,
        transaction_timestamp::date as activity_date,
        count(transaction_id) as daily_txn_count,
        sum(amount) as daily_txn_value
    from {{ ref('int_qualifying_transactions') }}
    group by
        merchant_id,
        transaction_timestamp::date
)

select *
from daily_activity