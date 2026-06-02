with products as (
    select * from {{ ref('dim_product') }}
),

sales_agg as (
    select
        product_sku,
        sum(shipped_units)                                                  as total_shipped_units,
        sum(case when fulfillment_status = 'fully_fulfilled' then 1 else 0 end)            as fully_fulfilled_orders,
        sum(case when fulfillment_status in ('partially_fulfilled','unfulfilled','units_unknown') then 1 else 0 end) as unfulfilled_orders,
        sum(case when fulfillment_status = 'cancelled' then 1 else 0 end)   as cancelled_orders,
        sum(gross_revenue)                                                  as total_gross_revenue
    from {{ ref('fct_sales_orders') }}
    where is_known_product = 1
    group by product_sku
),

pos_agg as (
    select
        product_sku,
        sum(case when pos_units > 0 then pos_units else 0 end)              as total_pos_units,
        sum(case when pos_units < 0 then pos_units else 0 end)              as total_pos_returns_units,
        sum(pos_sales)                                                      as total_pos_sales,
        count(distinct retailer_id)                                         as retailer_count
    from {{ ref('fct_retail_pos') }}
    where is_known_product = 1
    group by product_sku
),

inventory_agg as (
    select
        product_sku,
        sum(on_hand_qty)                                                    as current_on_hand,
        sum(in_transit_qty)                                                 as current_in_transit,
        sum(safety_stock_qty)                                               as safety_stock,
        max(has_negative_on_hand_flag)                                      as ever_had_negative_inventory,
        max(is_stockout)                                                    as ever_had_stockout
    from {{ ref('fct_inventory_snapshots') }}
    where is_known_product = 1
    group by product_sku
),

po_agg as (
    select
        product_sku,
        sum(ordered_qty)                                                    as supply_ordered_qty,
        sum(received_qty)                                                   as supply_received_qty,
        max(is_overdue)                                                     as has_overdue_po
    from {{ ref('fct_purchase_orders') }}
    where is_known_product = 1
    group by product_sku
),

marketing_agg as (
    select
        product_sku,
        count(distinct campaign_id)                                         as marketing_campaign_count,
        sum(total_spend)                                                    as total_marketing_spend,
        sum(total_impressions)                                              as total_marketing_impressions,
        sum(total_revenue)                                                  as marketing_attributed_revenue
    from {{ ref('mart_campaign_summary') }}
    where product_sku is not null
    group by product_sku
),

wos as (
    select product_sku, weeks_of_supply, supply_health_status
    from {{ ref('mart_inventory_weeks_of_supply') }}
)

select
    p.product_sku,
    p.product_name,
    p.division,
    p.brand_family,
    p.franchise,
    p.category,
    p.lifecycle_status,
    p.unit_cost,
    p.list_price,
    p.launch_date,
    p.discontinue_date,
    -- Sell-in (orders to customers)
    coalesce(sa.total_shipped_units, 0)                                     as total_shipped_units,
    coalesce(sa.fully_fulfilled_orders, 0)                                  as fully_fulfilled_orders,
    coalesce(sa.unfulfilled_orders, 0)                                      as unfulfilled_orders,
    coalesce(sa.cancelled_orders, 0)                                        as cancelled_orders,
    coalesce(sa.total_gross_revenue, 0)                                     as total_gross_revenue,
    -- Sell-through (retailer POS)
    coalesce(pa.total_pos_units, 0)                                         as total_pos_units,
    coalesce(pa.total_pos_returns_units, 0)                                 as total_pos_returns_units,
    coalesce(pa.total_pos_sales, 0)                                         as total_pos_sales,
    coalesce(pa.retailer_count, 0)                                          as retailer_count,
    -- Inventory position
    coalesce(ia.current_on_hand, 0)                                         as current_on_hand,
    coalesce(ia.current_in_transit, 0)                                      as current_in_transit,
    coalesce(ia.safety_stock, 0)                                            as safety_stock,
    coalesce(ia.ever_had_negative_inventory, 0)                             as ever_had_negative_inventory,
    coalesce(ia.ever_had_stockout, 0)                                       as ever_had_stockout,
    wos.weeks_of_supply,
    wos.supply_health_status,
    -- Inbound supply (POs from suppliers)
    coalesce(poa.supply_ordered_qty, 0)                                     as supply_ordered_qty,
    coalesce(poa.supply_received_qty, 0)                                    as supply_received_qty,
    coalesce(poa.has_overdue_po, 0)                                         as has_overdue_po,
    -- Marketing investment
    coalesce(ma.marketing_campaign_count, 0)                                as marketing_campaign_count,
    coalesce(ma.total_marketing_spend, 0)                                   as total_marketing_spend,
    coalesce(ma.total_marketing_impressions, 0)                             as total_marketing_impressions,
    coalesce(ma.marketing_attributed_revenue, 0)                            as marketing_attributed_revenue
from products p
left join sales_agg     sa  on p.product_sku = sa.product_sku
left join pos_agg       pa  on p.product_sku = pa.product_sku
left join inventory_agg ia  on p.product_sku = ia.product_sku
left join po_agg        poa on p.product_sku = poa.product_sku
left join marketing_agg ma  on p.product_sku = ma.product_sku
left join wos               on p.product_sku = wos.product_sku