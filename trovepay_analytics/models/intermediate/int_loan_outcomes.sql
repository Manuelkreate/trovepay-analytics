with loan_level as (
    select
        loan_id,
        count(*) as installment_count,
        sum(amount_due) as total_scheduled,
        max(loan_total_repaid) as total_repaid,
        count(*) filter (where installment_status = 'paid_on_time') as paid_on_time_count,
        count(*) filter (where installment_status = 'paid_late') as paid_late_count,
        count(*) filter (where installment_status = 'unpaid_overdue') as unpaid_overdue_count,
        max(days_late) as max_days_late,
        max(days_late) filter (where installment_status = 'unpaid_overdue') as max_days_overdue_open
    from {{ ref('int_repayment_allocation') }}
    group by loan_id
),

joined as (
    select
        l.loan_id,
        coalesce(ll.installment_count, 0) as installment_count,
        coalesce(ll.installment_count, 0) = l.tenure_months as is_schedule_complete,
        coalesce(ll.total_scheduled, 0) as total_scheduled,
        coalesce(ll.total_repaid, 0) as total_repaid,
        coalesce(ll.paid_on_time_count, 0) as paid_on_time_count,
        coalesce(ll.paid_late_count, 0) as paid_late_count,
        coalesce(ll.unpaid_overdue_count, 0) as unpaid_overdue_count,
        ll.max_days_late,
        ll.max_days_overdue_open
    from {{ ref('stg_loans') }} l
    left join loan_level ll using (loan_id)
)

select
    *,
    greatest(total_scheduled - total_repaid, 0) as outstanding_due_amount,
    is_schedule_complete and total_repaid >= total_scheduled as is_fully_repaid,
    (paid_late_count + unpaid_overdue_count) > 0 as is_late,
    coalesce(max_days_late > {{ var('delinquency_days') }}, false) as is_ever_delinquent,
    coalesce(max_days_overdue_open > {{ var('delinquency_days') }}, false) as is_currently_delinquent
from joined