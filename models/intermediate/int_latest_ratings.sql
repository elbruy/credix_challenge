with
    source as (select * from {{ ref("stg_ratings") }}),

    ranked_ratings as (
        select
            buyer_tax_id,
            rating,
            rating_created_at,
            -- latest ratings by date for each buyer
            row_number() over (
                partition by buyer_tax_id order by rating_created_at desc
            ) as rn
        from source
    )

select
    buyer_tax_id, rating as current_rating, rating_created_at as rating_last_updated_at
from ranked_ratings
where rn = 1
