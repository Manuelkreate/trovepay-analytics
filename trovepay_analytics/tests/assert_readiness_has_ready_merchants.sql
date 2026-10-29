select 1
where (
    select count(*)
    from {{ ref('int_credit_readiness') }}
    where rolling_ready_state
) = 0