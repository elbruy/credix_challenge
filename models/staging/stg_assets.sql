with
    source as (select * from {{ source("raw_data", "assets") }}),

    explicit_cast_and_rename as (
        select
            -- surrogate key creation
            to_hex(
                md5(
                    concat(
                        coalesce(cast(created_at as string), 'MISSING_TIMESTAMP'),
                        coalesce(cast(buyer_tax_id as string), 'MISSING_TAX_ID'),
                        coalesce(cast(face_value as string), 'MISSING_FACE_VALUE'),
                        coalesce(cast(settled_at as string), 'MISSING_SETTLEMENT_DATE'),
                        coalesce(buyer_state, 'MISSING_BUYER_STATE')
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

        from source
    )

select *
from explicit_cast_and_rename
-- remove invalid loans
where face_value > 0
