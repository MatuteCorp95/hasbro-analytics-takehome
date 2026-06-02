with shipments as (
    select * from {{ ref('stg_shipments') }}
),

deduped as (
    select *,
        row_number() over (
            partition by shipment_id
            order by shipped_units desc nulls last, tracking_number desc nulls last
        ) as rn
    from shipments
),

customer_check  as (select customer_id  from {{ ref('dim_customer') }}),
product_check   as (select product_sku  from {{ ref('dim_product') }}),
warehouse_check as (select warehouse_id from {{ ref('dim_warehouse') }}),
carrier_check   as (select carrier_id, contracted_transit_days from {{ ref('dim_carrier') }}),
order_check     as (select distinct order_id from {{ ref('fct_sales_orders') }}),

final as (
    select
        s.shipment_id,
        s.order_id,
        s.customer_id,
        s.product_sku,
        s.warehouse_id,
        s.carrier_id,
        case when c.customer_id  is not null then 1 else 0 end               as is_known_customer,
        case when p.product_sku  is not null then 1 else 0 end               as is_known_product,
        case when w.warehouse_id is not null then 1 else 0 end               as is_known_warehouse,
        case when ca.carrier_id  is not null then 1 else 0 end               as is_known_carrier,
        case when o.order_id     is not null then 1 else 0 end               as is_known_order,
        s.ship_date,
        s.delivery_date,
        s.shipment_status,
        s.shipped_units,
        s.freight_cost,
        s.currency,
        s.tracking_number,
        case
            when s.delivery_date is not null and s.ship_date is not null
            then julianday(s.delivery_date) - julianday(s.ship_date)
            else null
        end                                                                  as actual_transit_days,
        ca.contracted_transit_days,
        case
            when s.delivery_date is not null and s.ship_date is not null and ca.contracted_transit_days is not null
            then case
                when (julianday(s.delivery_date) - julianday(s.ship_date)) <= ca.contracted_transit_days then 1
                else 0
            end
            else null
        end                                                                  as is_on_time,
        case
            when s.delivery_date is not null and s.ship_date is not null
                 and julianday(s.delivery_date) < julianday(s.ship_date)
            then 1 else 0
        end                                                                  as has_delivery_before_ship_flag,
        case when nullif(trim(s.tracking_number),'') is null then 1 else 0 end as is_missing_tracking
    from deduped s
    left join customer_check  c  on s.customer_id  = c.customer_id
    left join product_check   p  on s.product_sku  = p.product_sku
    left join warehouse_check w  on s.warehouse_id = w.warehouse_id
    left join carrier_check   ca on s.carrier_id   = ca.carrier_id
    left join order_check     o  on s.order_id     = o.order_id
    where s.rn = 1
)

select * from final