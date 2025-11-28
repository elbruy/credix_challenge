with
    assets as (select * from {{ ref("stg_assets") }}),
    ratings as (select * from {{ ref("int_latest_ratings") }}),

    joined as (
        select
            a.asset_id,
            a.buyer_tax_id,
            a.face_value,
            a.created_at,
            a.due_date,
            a.settled_at,
            a.buyer_state,
            r.current_rating,
            date_diff(current_date, a.due_date, day) as days_overdue,
            a.collection_status as raw_status
        from assets a
        inner join ratings r on a.buyer_tax_id = r.buyer_tax_id
    ),

    with_status_logic as (
        select
            *,
            -- status based on business rule + data
            case
                -- hard coded statuses
                when raw_status in ('Settled', 'Repaid', 'Paid')
                then 'Settled'
                when raw_status = 'Canceled'
                then 'Canceled'

                -- business logic default (overdue)
                when raw_status in ('Default', 'Defaulted') or days_overdue > 30
                then 'Defaulted'

                -- else is active
                else 'Active'
            end as collection_status
        from joined
    ),

    final_metrics as (
        select
            *,
            case
                when collection_status = 'Defaulted'
                then 1.0
                when collection_status in ('Settled', 'Canceled')
                then 0.0
                when collection_status = 'Active'
                then
                    case
                        when current_rating = 'A'
                        then 0.01
                        when current_rating = 'B'
                        then 0.05
                        when current_rating = 'C'
                        then 0.10
                        when current_rating = 'D'
                        then 0.20
                        when current_rating = 'E'
                        then 0.30
                        when current_rating = 'F'
                        then 0.40
                        else 0.0
                    end
                else 0.0
            end as provision_rate
        from with_status_logic
    )

select *, (face_value * provision_rate) as cost_of_risk_amount
from final_metrics
