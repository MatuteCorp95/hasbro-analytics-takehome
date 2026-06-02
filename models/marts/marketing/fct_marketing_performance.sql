with perf as (
    select * from {{ ref('stg_marketing_performance') }}
),

deduped as (
    select *,
        row_number() over (
            partition by performance_date, campaign_id, platform
            order by impressions desc nulls last
        ) as rn
    from perf
),

campaigns as (select * from {{ ref('stg_marketing_campaigns') }}),
product_check as (select product_sku from {{ ref('dim_product') }}),

final as (
    select
        p.performance_date,
        p.campaign_id,
        p.platform,
        c.campaign_name,
        c.product_sku,
        c.channel,
        c.region,
        c.objective,
        case when c.campaign_id is not null then 1 else 0 end                as is_known_campaign,
        case when pr.product_sku is not null then 1 else 0 end               as is_known_product,
        p.impressions,
        p.clicks,
        p.video_views,
        p.spend,
        p.conversions,
        p.revenue,
        p.currency,
        case
            when coalesce(p.impressions, 0) <= 0 then null
            else round(cast(coalesce(p.clicks, 0) as real) / p.impressions, 6)
        end                                                                  as ctr,
        case
            when coalesce(p.clicks, 0) <= 0 then null
            else round(cast(coalesce(p.spend, 0) as real) / p.clicks, 4)
        end                                                                  as cpc,
        case
            when coalesce(p.impressions, 0) <= 0 then null
            else round(cast(coalesce(p.spend, 0) as real) / p.impressions * 1000, 4)
        end                                                                  as cpm,
        case
            when coalesce(p.spend, 0) <= 0 then null
            else round(cast(coalesce(p.revenue, 0) as real) / p.spend, 4)
        end                                                                  as roas,
        case when coalesce(p.clicks, 0) < 0 then 1 else 0 end                as has_negative_clicks_flag
    from deduped p
    left join campaigns       c  on p.campaign_id = c.campaign_id
    left join product_check   pr on c.product_sku = pr.product_sku
    where p.rn = 1
)

select * from final