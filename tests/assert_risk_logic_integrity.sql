-- simple test for provision rate
select *
from {{ ref("fct_credit_risk") }}
where
    -- settled loans must have 0 provision
    (collection_status = 'Settled' and provision_rate != 0)
    -- defaulted loans must be 100% provision
    or (collection_status = 'Defaulted' and provision_rate != 1.0)
    -- rating 'F' active loans must be 40%
    or (collection_status = 'Active' and current_rating = 'F' and provision_rate != 0.4)
