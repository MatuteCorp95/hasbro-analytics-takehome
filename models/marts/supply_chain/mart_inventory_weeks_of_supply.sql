with latest_inventory as (
    select
        product_sku,
        sum(on_hand_qty)         as total_on_hand_qty,
        sum(in_transit_qty)      as total_in_transit_qty,
        sum(safety_stock_qty)    as total_safety_stock_qty,
        max(snapshot_date)       as latest_snapshot_date
    from {{ ref('fct_inventory_snapshots') }}
    where is_known_product = 1
    group by product_sku
),

sales_velocity as (
    select
        product_sku,
        sum(case when pos_units > 0 then pos_units else 0 end) as total_pos_units_positive,
        count(distinct week_start_date)                        as weeks_with_pos_data,
        case
            when count(distinct week_start_date) = 0 then null
            else round(
                cast(sum(case when pos_units > 0 then pos_units else 0 end) as real)
                / count(distinct week_start_date),
                2
            )
        end                                                    as avg_weekly_pos_units
    from {{ ref('fct_retail_pos') }}
    where is_known_product = 1
    group by product_sku
),

final as (
    select
        i.product_sku,
        i.total_on_hand_qty,
        i.total_in_transit_qty,
        i.total_safety_stock_qty,
        i.latest_snapshot_date,
        coalesce(v.total_pos_units_positive, 0)              as total_pos_units_observed,
        v.weeks_with_pos_data,
        v.avg_weekly_pos_units,
        case
            when v.avg_weekly_pos_units is null or v.avg_weekly_pos_units <= 0 then null
            else round(
                cast(coalesce(i.total_on_hand_qty, 0) as real) / v.avg_weekly_pos_units,
                2
            )
        end                                                   as weeks_of_supply,
        case
            when v.avg_weekly_pos_units is null or v.avg_weekly_pos_units <= 0 then 'no_velocity_data'
            when coalesce(i.total_on_hand_qty, 0) <= 0 then 'stockout'
            when (cast(coalesce(i.total_on_hand_qty, 0) as real) / v.avg_weekly_pos_units) < 4 then 'low_coverage'
            when (cast(coalesce(i.total_on_hand_qty, 0) as real) / v.avg_weekly_pos_units) > 26 then 'overstock'
            else 'healthy'
        end                                                   as supply_health_status
    from latest_inventory i
    left join sales_velocity v on i.product_sku = v.product_sku
)

select * from final