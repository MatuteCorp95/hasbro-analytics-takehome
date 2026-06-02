with inv as (
    select * from {{ ref('stg_inventory_snapshots') }}
),

deduped as (
    select *,
        row_number() over (
            partition by snapshot_date, warehouse_id, product_sku
            order by on_hand_qty desc nulls last
        ) as rn
    from inv
),

product_check   as (select product_sku  from {{ ref('dim_product') }}),
warehouse_check as (select warehouse_id from {{ ref('dim_warehouse') }}),

final as (
    select
        i.snapshot_date,
        i.warehouse_id,
        i.product_sku,
        case when p.product_sku  is not null then 1 else 0 end               as is_known_product,
        case when w.warehouse_id is not null then 1 else 0 end               as is_known_warehouse,
        i.on_hand_qty,
        i.allocated_qty,
        i.available_qty,
        i.in_transit_qty,
        i.safety_stock_qty,
        i.unit_of_measure,
        i.inventory_status,
        case when coalesce(i.on_hand_qty, 0)    < 0 then 1 else 0 end        as has_negative_on_hand_flag,
        case when coalesce(i.available_qty, 0)  < 0 then 1 else 0 end        as has_negative_available_flag,
        case
            when coalesce(i.available_qty, 0) <= 0
                 and coalesce(i.inventory_status, '') != 'prelaunch'
            then 1 else 0
        end                                                                  as is_stockout,
        case
            when coalesce(i.allocated_qty, 0) > coalesce(i.on_hand_qty, 0)
            then 1 else 0
        end                                                                  as is_oversold,
        case
            when coalesce(i.available_qty, 0) < coalesce(i.safety_stock_qty, 0)
                 and coalesce(i.inventory_status, '') != 'prelaunch'
            then 1 else 0
        end                                                                  as is_below_safety_stock
    from deduped i
    left join product_check   p on i.product_sku  = p.product_sku
    left join warehouse_check w on i.warehouse_id = w.warehouse_id
    where i.rn = 1
)

select * from final