select
    l.loan_id,
    l.merchant_id,
    l.disbursement_date::date as disbursement_date,
    date_trunc('month', l.disbursement_date)::date as disbursement_month,
    l.loan_amount,
    l.tenure_months,
    l.maturity_date::date as maturity_date,
    o.is_schedule_complete as is_matured,

    m.business_type,
    m.category,
    m.state,
    m.cohort as merchant_cohort,

    o.installment_count,
    o.total_scheduled,
    o.total_repaid,
    round(o.total_repaid / nullif(o.total_scheduled, 0), 4) as repayment_ratio,
    o.outstanding_due_amount,
    o.paid_on_time_count,
    o.paid_late_count,
    o.unpaid_overdue_count,
    o.max_days_late,
    o.is_fully_repaid,
    o.is_late,
    o.is_ever_delinquent,
    o.is_currently_delinquent
from {{ ref('stg_loans') }} l
left join {{ ref('stg_merchants') }} m using (merchant_id)
left join {{ ref('int_loan_outcomes') }} o using (loan_id)