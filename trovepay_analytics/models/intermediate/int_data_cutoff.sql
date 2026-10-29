select greatest(
    (select max(transaction_timestamp)::date from {{ ref('stg_transactions') }}),
    (select max(repayment_date)::date from {{ ref('stg_repayments') }})
) as data_cutoff