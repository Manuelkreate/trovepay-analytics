select
    disbursement_month,
    business_type,
    count(*) as loans_disbursed,
    sum(loan_amount) as total_disbursed,
    round(avg(loan_amount), 2) as avg_loan_amount,
    count(*) filter (where is_matured) as matured_loans,
    count(*) filter (where is_matured and is_fully_repaid) as matured_fully_repaid,
    round(
        count(*) filter (where is_matured and is_fully_repaid)
        / nullif(count(*) filter (where is_matured), 0), 4
    ) as fully_repaid_rate_matured,
        round(
        sum(total_repaid) filter (where is_matured)
        / nullif(sum(total_scheduled) filter (where is_matured), 0), 4
    ) as collection_rate_matured,
    round(count(*) filter (where is_late) / count(*), 4) as late_rate,
    round(count(*) filter (where is_ever_delinquent) / count(*), 4) as ever_delinquent_rate,
    round(count(*) filter (where is_currently_delinquent) / count(*), 4) as currently_delinquent_rate,
    sum(outstanding_due_amount) as total_outstanding
from {{ ref('mart_loan_performance') }}
group by disbursement_month, business_type