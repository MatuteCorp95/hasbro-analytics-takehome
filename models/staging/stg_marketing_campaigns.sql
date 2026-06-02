with source as (
    select * from {{ source('raw', 'marketing_campaigns_raw') }}
),

sku_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'sku_normalization' and is_active = 1
),

platform_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'platform' and is_active = 1
),

region_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'region' and is_active = 1
),

standardized as (
    select
        trim(s.campaign_id)                                                  as campaign_id,
        trim(s.campaign_name)                                                as campaign_name,
        coalesce(pm.standard_value, nullif(trim(s.platform),''))             as platform,
        trim(s.platform)                                                     as platform_raw,
        nullif(trim(s.campaign_start_date),'')                               as campaign_start_date,
        nullif(trim(s.campaign_end_date),'')                                 as campaign_end_date,
        coalesce(sm.standard_value, trim(s.product_sku))                     as product_sku,
        trim(s.product_sku)                                                  as product_sku_raw,
        nullif(trim(s.channel),'')                                           as channel,
        coalesce(rm.standard_value, nullif(trim(s.region),''))               as region,
        trim(s.region)                                                       as region_raw,
        nullif(trim(s.objective),'')                                         as objective,
        case
            when nullif(trim(s.budget),'') is null then null
            when trim(s.budget) glob '*[A-Za-z]*' then null
            else cast(s.budget as real)
        end                                                                  as budget,
        upper(trim(s.currency))                                              as currency,
        nullif(trim(s.taxonomy_code),'')                                     as taxonomy_code
    from source s
    left join sku_map sm on lower(trim(s.product_sku)) = lower(trim(sm.raw_value))
    left join platform_map pm on lower(trim(s.platform)) = lower(trim(pm.raw_value))
    left join region_map rm on lower(trim(s.region)) = lower(trim(rm.raw_value))
)

select * from standardized