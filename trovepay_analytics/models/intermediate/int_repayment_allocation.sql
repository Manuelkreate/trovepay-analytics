with schedule as (
    select
        schedule_id,
        loan_id,
        installment_number,
        due_date::date as due_date,
        amount_due,
        sum(amount_due) over (
            partition by loan_id
            order by due_date, installment_number
            rows between unbounded preceding and current row
        ) as cum_due_end
    from {{ ref('stg_repayment_schedule') }}
),

schedule_bounds as (
    select
        *,
        cum_due_end - amount_due as cum_due_start
    from schedule
),

repayments_running as (
    select
        loan_id,
        repayment_date,
        sum(amount) over (
            partition by loan_id
            order by repayment_date, repayment_id
            rows between unbounded preceding and current row
        ) as cum_repaid
    from {{ ref('stg_repayments') }}
),

loan_repaid as (
    select loan_id, sum(amount) as total_repaid
    from {{ ref('stg_repayments') }}
    group by loan_id
),

covered as (
    select
        s.schedule_id,
        min(r.repayment_date)::date as covered_date
    from schedule_bounds s
    join repayments_running r
        on r.loan_id = s.loan_id
        and r.cum_repaid >= s.cum_due_end
    group by s.schedule_id
)

select
    s.schedule_id,
    s.loan_id,
    s.installment_number,
    s.due_date,
    s.amount_due,
    s.cum_due_end,
    coalesce(lr.total_repaid, 0) as loan_total_repaid,
    least(
        s.amount_due,
        greatest(0, coalesce(lr.total_repaid, 0) - s.cum_due_start)
    ) as amount_allocated,
    c.covered_date,
    case
        when c.covered_date is not null and c.covered_date <= s.due_date then 'paid_on_time'
        when c.covered_date is not null then 'paid_late'
        when s.due_date > dc.data_cutoff then 'not_yet_due'
        else 'unpaid_overdue'
    end as installment_status,
    case
        when c.covered_date is not null then greatest(0, c.covered_date - s.due_date)
        when s.due_date > dc.data_cutoff then null
        else dc.data_cutoff - s.due_date
    end as days_late
from schedule_bounds s
left join covered c using (schedule_id)
left join loan_repaid lr using (loan_id)
cross join {{ ref('int_data_cutoff') }} dc