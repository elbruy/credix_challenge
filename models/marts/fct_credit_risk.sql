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
            case
                when a.collection_status in ('Settled', 'Repaid', 'Paid')
                then 'Settled'
                when a.collection_status in ('Default', 'Defaulted')
                then 'Defaulted'
                when a.collection_status = 'Canceled'
                then 'Canceled'
                else 'Active'
            end as collection_status,
            r.current_rating
        from assets a
        inner join ratings r on a.buyer_tax_id = r.buyer_tax_id
    ),

    with_provision_rate as (
        select
            *,
            date_diff(current_date, due_date, day) as days_overdue,
            case
                -- no risk
                when collection_status in ('Settled', 'Canceled')
                then 0.0

                -- defaulted already
                when
                    collection_status = 'Defaulted'
                    or date_diff(current_date, due_date, day) > 30
                then 1.0

                -- active
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
            end as provision_rate
        from joined
    )

select *, (face_value * provision_rate) as cost_of_risk_amount
from with_provision_rate
