with perf as (
    select * from {{ ref('fct_marketing_performance') }}
),

agg as (
    select
        campaign_id,
        campaign_name,
        platform,
        channel,
        region,
        objective,
        product_sku,
        max(is_known_campaign)                                              as is_known_campaign,
        min(performance_date)                                               as first_performance_date,
        max(performance_date)                                               as last_performance_date,
        sum(impressions)                                                    as total_impressions,
        sum(case when clicks > 0 then clicks else 0 end)                    as total_clicks_positive,
        sum(video_views)                                                    as total_video_views,
        sum(spend)                                                          as total_spend,
        sum(conversions)                                                    as total_conversions,
        sum(revenue)                                                        as total_revenue,
        max(currency)                                                       as currency,
        count(*)                                                            as performance_record_count
    from perf
    group by campaign_id, campaign_name, platform, channel, region, objective, product_sku
)

select
    *,
    case
        when coalesce(total_impressions, 0) <= 0 then null
        else round(cast(total_clicks_positive as real) / total_impressions, 6)
    end                                                                     as overall_ctr,
    case
        when coalesce(total_spend, 0) <= 0 then null
        else round(cast(total_revenue as real) / total_spend, 4)
    end                                                                     as overall_roas,
    case
        when coalesce(total_conversions, 0) <= 0 then null
        else round(cast(total_spend as real) / total_conversions, 4)
    end                                                                     as cost_per_conversion
from agg