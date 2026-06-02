with source as (
    select * from {{ source('raw', 'customers_raw') }}
),

channel_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'channel' and is_active = 1
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
        trim(s.customer_id)                                                  as customer_id,
        trim(s.customer_name)                                                as customer_name,
        coalesce(cm.standard_value, nullif(trim(s.channel),''))              as channel,
        coalesce(rm.standard_value, nullif(trim(s.region),''))               as region,
        coalesce(co.standard_value, nullif(trim(s.country),''))              as country,
        case
            when lower(replace(replace(trim(s.tier),'-',''),' ','')) = 'tier1' then 'Tier 1'
            when lower(replace(replace(trim(s.tier),'-',''),' ','')) = 'tier2' then 'Tier 2'
            when lower(replace(replace(trim(s.tier),'-',''),' ','')) = 'tier3' then 'Tier 3'
            when lower(trim(s.tier)) = 'strategic' then 'Strategic'
            else nullif(trim(s.tier),'')
        end                                                                  as tier,
        case when upper(trim(s.active_flag)) = 'Y' then 1 else 0 end         as is_active,
        nullif(trim(s.parent_customer_id), '')                               as parent_customer_id
    from source s
    left join channel_map cm on lower(trim(s.channel)) = lower(trim(cm.raw_value))
    left join region_map  rm on lower(trim(s.region))  = lower(trim(rm.raw_value))
    left join country_map co on lower(trim(s.country)) = lower(trim(co.raw_value))
)

select * from standardized