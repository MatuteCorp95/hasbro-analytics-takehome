with source as (
    select * from {{ source('raw', 'marketing_performance_raw') }}
),

platform_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'platform' and is_active = 1
),

standardized as (
    select
        nullif(trim(s.performance_date),'')                                  as performance_date,
        trim(s.campaign_id)                                                  as campaign_id,
        coalesce(pm.standard_value, nullif(trim(s.platform),''))             as platform,
        trim(s.platform)                                                     as platform_raw,
        case
            when nullif(trim(s.impressions),'') is null then null
            when cast(cast(trim(s.impressions) as integer) as text) != trim(s.impressions) then null
            else cast(s.impressions as integer)
        end                                                                  as impressions,
        case
            when nullif(trim(s.clicks),'') is null then null
            when cast(cast(trim(s.clicks) as integer) as text) != trim(s.clicks) then null
            else cast(s.clicks as integer)
        end                                                                  as clicks,
        case
            when nullif(trim(s.video_views),'') is null then null
            when cast(cast(trim(s.video_views) as integer) as text) != trim(s.video_views) then null
            else cast(s.video_views as integer)
        end                                                                  as video_views,
        case
            when nullif(trim(s.spend),'') is null then null
            when trim(s.spend) glob '*[A-Za-z]*' then null
            else cast(s.spend as real)
        end                                                                  as spend,
        case
            when nullif(trim(s.conversions),'') is null then null
            when cast(cast(trim(s.conversions) as integer) as text) != trim(s.conversions) then null
            else cast(s.conversions as integer)
        end                                                                  as conversions,
        case
            when nullif(trim(s.revenue),'') is null then null
            when trim(s.revenue) glob '*[A-Za-z]*' then null
            else cast(s.revenue as real)
        end                                                                  as revenue,
        upper(trim(s.currency))                                              as currency
    from source s
    left join platform_map pm on lower(trim(s.platform)) = lower(trim(pm.raw_value))
)

select * from standardized