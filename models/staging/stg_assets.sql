with
    source as (select * from {{ source("raw_data", "assets") }}),

    explicit_cast_and_rename as (
        select distinct
            -- surrogate key creation (coalesce avoids breaking BQ)
            to_hex(
                md5(
                    concat(
                        coalesce(cast(created_at as string), 'NO_CREATED_AT'),
                        coalesce(cast(buyer_tax_id as string), 'NO_TAX_ID'),
                        coalesce(cast(face_value as string), 'NO_FACE_VALUE'),
                        coalesce(cast(settled_at as string), 'NO_SETTLEMENT_DATE'),
                        coalesce(cast(buyer_state as string), 'NO_BUYER_STATE'),
                        coalesce(cast(due_date as string), 'NO_DUE_DATE'),
                        coalesce(cast(collection_status as string), 'NO_STATUS')
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
