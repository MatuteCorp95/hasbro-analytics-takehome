with source as (
    select * from {{ source('raw', 'suppliers_raw') }}
),

supplier_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'supplier' and is_active = 1
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
        trim(s.supplier_id)                                                  as supplier_id,
        coalesce(sm.standard_value, trim(s.supplier_name))                   as supplier_name,
        trim(s.supplier_name)                                                as supplier_name_raw,
        coalesce(rm.standard_value, nullif(trim(s.supplier_region),''))     as supplier_region,
        coalesce(co.standard_value, nullif(trim(s.country),''))             as country,
        case when upper(trim(s.preferred_flag)) = 'Y' then 1 else 0 end     as is_preferred,
        case
            when s.lead_time_days is null or trim(s.lead_time_days) = '' then null
            when cast(s.lead_time_days as integer) > 0 then cast(s.lead_time_days as integer)
            else null
        end                                                                  as lead_time_days,
        case when upper(trim(s.active_flag)) = 'Y' then 1 else 0 end         as is_active
    from source s
    left join supplier_map sm on lower(trim(s.supplier_name)) = lower(trim(sm.raw_value))
    left join region_map rm on lower(trim(s.supplier_region)) = lower(trim(rm.raw_value))
    left join country_map co on lower(trim(s.country)) = lower(trim(co.raw_value))
)

select * from standardized