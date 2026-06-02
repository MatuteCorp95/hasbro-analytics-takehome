with orders as (
    select * from {{ ref('stg_sales_orders') }}
),

deduped as (
    select *,
        row_number() over (
            partition by order_id, order_line_id, product_sku
            order by ordered_units desc nulls last, customer_id
        ) as rn
    from orders
),

customer_check as (select customer_id from {{ ref('dim_customer') }}),
product_check as (select product_sku from {{ ref('dim_product') }}),

final as (
    select
        o.order_id,
        o.order_line_id,
        o.customer_id,
        o.product_sku,
        case when c.customer_id is not null then 1 else 0 end                as is_known_customer,
        case when p.product_sku is not null then 1 else 0 end                as is_known_product,
        o.order_date,
        o.requested_ship_date,
        o.ship_date,
        o.order_status,
        o.ordered_units,
        o.shipped_units,
        case
            when o.ordered_units is null or o.ordered_units = 0 then null
            else round(cast(coalesce(o.shipped_units, 0) as real) / o.ordered_units, 4)
        end                                                                  as fill_rate,
        case
            when o.order_status = 'cancelled' then 'cancelled'
            when o.order_status = 'open' then 'open'
            when o.ordered_units is null then 'units_unknown'
            when coalesce(o.shipped_units, 0) >= o.ordered_units then 'fully_fulfilled'
            when coalesce(o.shipped_units, 0) > 0 then 'partially_fulfilled'
            else 'unfulfilled'
        end                                                                  as fulfillment_status,
        case
            when o.ship_date is not null and o.order_date is not null
            then julianday(o.ship_date) - julianday(o.order_date)
            else null
        end                                                                  as days_to_ship,
        case
            when o.ship_date is not null and o.order_date is not null
                 and julianday(o.ship_date) < julianday(o.order_date)
            then 1 else 0
        end                                                                  as has_ship_before_order_flag,
        o.unit_price,
        round(coalesce(o.unit_price, 0) * coalesce(o.shipped_units, 0), 2)   as gross_revenue,
        o.currency,
        o.cancel_reason
    from deduped o
    left join customer_check c on o.customer_id = c.customer_id
    left join product_check  p on o.product_sku = p.product_sku
    where o.rn = 1
)

select * from final