with loan_level as (
    select
        loan_id,
        count(*) as installment_count,
        sum(amount_due) as total_scheduled,
        max(loan_total_repaid) as total_repaid,
        count(*) filter (where installment_status = 'paid_on_time') as paid_on_time_count,
        count(*) filter (where installment_status = 'paid_late') as paid_late_count,
        count(*) filter (where installment_status = 'unpaid_overdue') as unpaid_overdue_count,
        count(*) filter (where installment_status = 'not_yet_due') as not_yet_due_count,
        max(days_late) as max_days_late,
        max(days_late) filter (where installment_status = 'unpaid_overdue') as max_days_overdue_open
    from {{ ref('int_repayment_allocation') }}
    group by loan_id
)

select
    *,
    greatest(total_scheduled - total_repaid, 0) as outstanding_scheduled_amount,
    total_repaid >= total_scheduled as is_fully_repaid,
    (paid_late_count + unpaid_overdue_count) > 0 as is_late,
   coalesce(max_days_late > {{ var('delinquency_days') }}, false) as is_ever_delinquent,
   coalesce(max_days_overdue_open > {{ var('delinquency_days') }}, false) as is_currently_delinquent
from loan_level