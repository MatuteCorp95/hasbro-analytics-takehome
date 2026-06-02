with source as (
    select * from {{ source('raw', 'sales_orders_raw') }}
),

sku_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'sku_normalization' and is_active = 1
),

standardized as (
    select
        trim(s.order_id)                                                     as order_id,
        cast(s.order_line_id as integer)                                     as order_line_id,
        trim(s.customer_id)                                                  as customer_id,
        coalesce(sm.standard_value, trim(s.product_sku))                     as product_sku,
        trim(s.product_sku)                                                  as product_sku_raw,
        nullif(trim(s.order_date),'')                                        as order_date,
        nullif(trim(s.requested_ship_date),'')                               as requested_ship_date,
        nullif(trim(s.ship_date),'')                                         as ship_date,
        lower(trim(s.order_status))                                          as order_status,
        case
            when nullif(trim(s.ordered_units),'') is null then null
            when cast(cast(trim(s.ordered_units) as integer) as text) != trim(s.ordered_units) then null
            else cast(s.ordered_units as integer)
        end                                                                  as ordered_units,
        case
            when nullif(trim(s.shipped_units),'') is null then null
            when cast(cast(trim(s.shipped_units) as integer) as text) != trim(s.shipped_units) then null
            else cast(s.shipped_units as integer)
        end                                                                  as shipped_units,
        case
            when nullif(trim(s.unit_price),'') is null then null
            when trim(s.unit_price) glob '*[A-Za-z]*' then null
            else cast(s.unit_price as real)
        end                                                                  as unit_price,
        upper(trim(s.currency))                                              as currency,
        nullif(trim(s.cancel_reason),'')                                     as cancel_reason
    from source s
    left join sku_map sm on lower(trim(s.product_sku)) = lower(trim(sm.raw_value))
)

select * from standardized