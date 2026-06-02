with carriers as (
    select * from {{ ref('stg_carrier_performance') }}
),

ranked as (
    select *,
        row_number() over (
            partition by carrier_id
            order by
                case when contracted_transit_days is null then 1 else 0 end,
                case when region = 'EMEA' then 0 else 1 end,
                carrier_name
        ) as rn
    from carriers
)

select
    carrier_id,
    carrier_name,
    service_level,
    region,
    contracted_transit_days,
    is_active
from ranked
where rn = 1