with source as (
    select * from {{ source('raw', 'carrier_performance_raw') }}
),

region_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'region' and is_active = 1
),

standardized as (
    select
        trim(s.carrier_id)                                                   as carrier_id,
        trim(s.carrier_name)                                                 as carrier_name,
        nullif(trim(s.service_level),'')                                     as service_level,
        coalesce(rm.standard_value, nullif(trim(s.region),''))               as region,
        case
            when s.contracted_transit_days is null or trim(s.contracted_transit_days) = '' then null
            when cast(s.contracted_transit_days as integer) > 0 then cast(s.contracted_transit_days as integer)
            else null
        end                                                                  as contracted_transit_days,
        case when upper(trim(s.active_flag)) = 'Y' then 1 else 0 end         as is_active
    from source s
    left join region_map rm on lower(trim(s.region)) = lower(trim(rm.raw_value))
)

select * from standardized