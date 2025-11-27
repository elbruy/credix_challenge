{{
    config(
        materialized="table",
    )
}}

with
    days as (
        -- cover all historical and future data
        select
            date_sub(current_date(), interval 5 year) as start_date,
            date_add(current_date(), interval 5 year) as end_date
    )

select cast(d as date) as date_day
from days, unnest(generate_date_array(start_date, end_date, interval 1 day)) as d
