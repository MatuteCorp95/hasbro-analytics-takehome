with warehouses as (
    select * from {{ ref('stg_warehouse_locations') }}
),

ranked as (
    select *,
        row_number() over (
            partition by warehouse_id
            order by
                case when timezone like '%/%' then 0 else 1 end,
                case when warehouse_id_raw = warehouse_id then 0 else 1 end,
                warehouse_name
        ) as rn
    from warehouses
)

select
    warehouse_id,
    warehouse_name,
    warehouse_type,
    region,
    country,
    timezone,
    is_active
from ranked
where rn = 1