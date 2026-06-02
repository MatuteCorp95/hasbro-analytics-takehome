with suppliers as (
    select * from {{ ref('stg_suppliers') }}
),

ranked as (
    select *,
        row_number() over (
            partition by supplier_id
            order by
                case when lead_time_days is null then 1 else 0 end,
                length(coalesce(country, '~~~~~')),
                supplier_name
        ) as rn
    from suppliers
)

select
    supplier_id,
    supplier_name,
    supplier_region,
    country,
    is_preferred,
    lead_time_days,
    is_active
from ranked
where rn = 1