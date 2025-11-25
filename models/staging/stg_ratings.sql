with
    source as (select * from {{ source("raw_data", "ratings") }}),

    explicit_cast_and_rename as (

        select
            -- to match assets table
            cast(tax_id as string) as buyer_tax_id,
            rating,
            -- so it is distinct from asset creation date
            cast(created_at as timestamp) as rating_created_at

        from source

    )

select *
from explicit_cast_and_rename
