with
    source as (select * from {{ source("raw_data", "assets") }}),

    -- remove exact duplicates that come from new raw file
    deduped as (select distinct * from source),

    explicit_cast_and_rename as (
        select
            -- surrogate key creation
            to_hex(
                md5(
                    concat(
                        cast(created_at as string),
                        cast(buyer_tax_id as string),
                        cast(face_value as string)
                    )
                )
            ) as asset_id,
            cast(buyer_tax_id as string) as buyer_tax_id,
            collection_status,
            seller_name,
            buyer_state,
            cast(face_value as numeric) as face_value,
            cast(created_at as timestamp) as created_at,
            cast(settled_at as timestamp) as settled_at,
            cast(due_date as date) as due_date

        from deduped
    )

select *
from explicit_cast_and_rename
-- remove invalid loans
where face_value > 0
