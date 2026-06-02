with pos as (
    select * from {{ ref('stg_purchase_orders') }}
),

deduped as (
    select *,
        row_number() over (
            partition by po_id, po_line_id, product_sku
            order by ordered_qty desc nulls last, supplier_id
        ) as rn
    from pos
),

supplier_check  as (select supplier_id  from {{ ref('dim_supplier') }}),
product_check   as (select product_sku  from {{ ref('dim_product') }}),
warehouse_check as (select warehouse_id from {{ ref('dim_warehouse') }}),

final as (
    select
        o.po_id,
        o.po_line_id,
        o.supplier_id,
        o.product_sku,
        o.warehouse_id,
        case when s.supplier_id  is not null then 1 else 0 end               as is_known_supplier,
        case when p.product_sku  is not null then 1 else 0 end               as is_known_product,
        case when w.warehouse_id is not null then 1 else 0 end               as is_known_warehouse,
        o.po_create_date,
        o.requested_delivery_date,
        o.received_date,
        o.po_status,
        o.ordered_qty,
        o.received_qty,
        case
            when o.received_qty is null or o.ordered_qty is null then null
            else o.received_qty - o.ordered_qty
        end                                                                  as received_qty_variance,
        case
            when o.received_date is not null and o.po_create_date is not null
            then julianday(o.received_date) - julianday(o.po_create_date)
            else null
        end                                                                  as actual_lead_time_days,
        case
            when o.received_date is not null and o.po_create_date is not null
                 and julianday(o.received_date) < julianday(o.po_create_date)
            then 1 else 0
        end                                                                  as has_received_before_created_flag,
        case
            when o.po_status = 'open'
                 and o.received_date is null
                 and o.requested_delivery_date is not null
                 and julianday(o.requested_delivery_date) < julianday('now')
            then 1 else 0
        end                                                                  as is_overdue,
        o.unit_cost,
        round(coalesce(o.unit_cost, 0) * coalesce(o.received_qty, 0), 2)     as received_cost,
        o.currency
    from deduped o
    left join supplier_check  s on o.supplier_id  = s.supplier_id
    left join product_check   p on o.product_sku  = p.product_sku
    left join warehouse_check w on o.warehouse_id = w.warehouse_id
    where o.rn = 1
)

select * from final