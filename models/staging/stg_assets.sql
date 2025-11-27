with
    source as (select * from {{ source("raw_data", "assets") }}),

    explicit_cast_and_rename as (

        select
            -- asset_id is missing! 
            -- creates a hash of unique-ish columns to serve as the ID
            to_hex(
                md5(
                    concat(
                        cast(created_at as string),
                        cast(buyer_tax_id as string),
                        cast(face_value as string)
                    )
                )
            ) as asset_id,
            -- protects leading zeros 
            cast(buyer_tax_id as string) as buyer_tax_id,
            collection_status,
            seller_name,
            buyer_state,
            -- no floating point error
            cast(face_value as numeric) as face_value,
            -- enforces timestamp
            cast(created_at as timestamp) as created_at,
            cast(settled_at as timestamp) as settled_at,
            cast(due_date as date) as due_date

        from source

    )

select *
from explicit_cast_and_rename
