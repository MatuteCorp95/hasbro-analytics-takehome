with pos as (
    select * from {{ ref('stg_retail_pos') }}
),

deduped as (
    select *,
        row_number() over (
            partition by retailer_id, week_start_date, product_sku
            order by pos_units desc nulls last
        ) as rn
    from pos
),

customer_check as (select customer_id from {{ ref('dim_customer') }}),
product_check  as (select product_sku  from {{ ref('dim_product') }}),

final as (
    select
        p.retailer_id,
        p.week_start_date,
        p.product_sku,
        case when c.customer_id is not null then 1 else 0 end                as is_known_retailer,
        case when pr.product_sku is not null then 1 else 0 end               as is_known_product,
        p.store_count,
        p.pos_units,
        p.pos_sales,
        p.on_hand_units,
        p.on_order_units,
        case
            when coalesce(p.on_hand_units, 0) <= 0 then null
            else round(cast(coalesce(p.pos_units, 0) as real) / p.on_hand_units, 4)
        end                                                                  as sell_through_rate,
        case
            when coalesce(p.store_count, 0) <= 0 then null
            else round(cast(coalesce(p.pos_units, 0) as real) / p.store_count, 4)
        end                                                                  as pos_units_per_store,
        case when coalesce(p.pos_units, 0) < 0 then 1 else 0 end             as has_negative_pos_flag,
        case when coalesce(p.on_hand_units, 0) < 0 then 1 else 0 end         as has_negative_on_hand_flag,
        p.currency,
        p.feed_date
    from deduped p
    left join customer_check c  on p.retailer_id = c.customer_id
    left join product_check  pr on p.product_sku = pr.product_sku
    where p.rn = 1
)

select * from final