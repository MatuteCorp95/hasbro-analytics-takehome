with source as (
    select * from {{ source('raw', 'shipments_raw') }}
),

sku_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'sku_normalization' and is_active = 1
),

warehouse_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'warehouse_normalization' and is_active = 1
),

standardized as (
    select
        trim(s.shipment_id)                                                  as shipment_id,
        trim(s.order_id)                                                     as order_id,
        trim(s.customer_id)                                                  as customer_id,
        coalesce(sm.standard_value, trim(s.product_sku))                     as product_sku,
        trim(s.product_sku)                                                  as product_sku_raw,
        coalesce(wm.standard_value, trim(s.warehouse_id))                    as warehouse_id,
        trim(s.carrier_id)                                                   as carrier_id,
        nullif(trim(s.ship_date),'')                                         as ship_date,
        nullif(trim(s.delivery_date),'')                                     as delivery_date,
        lower(trim(s.shipment_status))                                       as shipment_status,
        case
            when nullif(trim(s.shipped_units),'') is null then null
            when cast(cast(trim(s.shipped_units) as integer) as text) != trim(s.shipped_units) then null
            else cast(s.shipped_units as integer)
        end                                                                  as shipped_units,
        case
            when nullif(trim(s.freight_cost),'') is null then null
            when trim(s.freight_cost) glob '*[A-Za-z]*' then null
            else cast(s.freight_cost as real)
        end                                                                  as freight_cost,
        upper(trim(s.currency))                                              as currency,
        nullif(trim(s.tracking_number),'')                                   as tracking_number
    from source s
    left join sku_map sm on lower(trim(s.product_sku)) = lower(trim(sm.raw_value))
    left join warehouse_map wm on lower(trim(s.warehouse_id)) = lower(trim(wm.raw_value))
)

select * from standardized