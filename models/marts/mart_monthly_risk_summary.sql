with fct_risk as (select * from {{ ref("fct_credit_risk") }})

select
    date_trunc(due_date, month) as risk_month,
    buyer_state,
    current_rating,
    count(distinct asset_id) as total_loans,
    sum(face_value) as total_exposure,
    sum(cost_of_risk_amount) as total_expected_loss,
    -- to avoid division by zero
    safe_divide(sum(cost_of_risk_amount), sum(face_value)) as avg_provision_rate

from fct_risk
where due_date is not null
group by 1, 2, 3
order by 1 desc, 2
