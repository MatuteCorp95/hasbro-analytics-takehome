with source as (
    select * from {{ source('raw', 'warehouse_locations_raw') }}
),

warehouse_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'warehouse_normalization' and is_active = 1
),

region_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'region' and is_active = 1
),

country_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'country' and is_active = 1
),

standardized as (
    select
        coalesce(wm.standard_value, trim(s.warehouse_id))                    as warehouse_id,
        trim(s.warehouse_id)                                                 as warehouse_id_raw,
        trim(s.warehouse_name)                                               as warehouse_name,
        case
            when upper(trim(s.warehouse_type)) in ('DISTRIBUTION CENTER','DC') then 'Distribution Center'
            when upper(trim(s.warehouse_type)) = '3PL' then '3PL'
            when nullif(trim(s.warehouse_type),'') is null or upper(trim(s.warehouse_type)) = 'UNKNOWN' then null
            else trim(s.warehouse_type)
        end                                                                  as warehouse_type,
        coalesce(rm.standard_value, nullif(trim(s.region),''))               as region,
        coalesce(co.standard_value, nullif(trim(s.country),''))              as country,
        nullif(trim(s.timezone),'')                                          as timezone,
        case when upper(trim(s.active_flag)) = 'Y' then 1 else 0 end         as is_active
    from source s
    left join warehouse_map wm on lower(trim(s.warehouse_id)) = lower(trim(wm.raw_value))
    left join region_map rm on lower(trim(s.region)) = lower(trim(rm.raw_value))
    left join country_map co on lower(trim(s.country)) = lower(trim(co.raw_value))
)

select * from standardized