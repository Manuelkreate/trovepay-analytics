select
    transaction_id,
    merchant_id,
    terminal_id,
    transaction_timestamp,
    amount,
    status,
    reversed_at
from {{ ref('stg_transactions') }}
where status = 'successful' 

