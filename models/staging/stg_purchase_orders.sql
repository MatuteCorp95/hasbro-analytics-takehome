with source as (
    select * from {{ source('raw', 'purchase_orders_raw') }}
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
        trim(s.po_id)                                                        as po_id,
        cast(s.po_line_id as integer)                                        as po_line_id,
        trim(s.supplier_id)                                                  as supplier_id,
        coalesce(sm.standard_value, trim(s.product_sku))                     as product_sku,
        trim(s.product_sku)                                                  as product_sku_raw,
        coalesce(wm.standard_value, trim(s.warehouse_id))                    as warehouse_id,
        nullif(trim(s.po_create_date),'')                                    as po_create_date,
        nullif(trim(s.requested_delivery_date),'')                           as requested_delivery_date,
        nullif(trim(s.received_date),'')                                     as received_date,
        lower(trim(s.po_status))                                             as po_status,
        case
            when nullif(trim(s.ordered_qty),'') is null then null
            when cast(cast(trim(s.ordered_qty) as integer) as text) != trim(s.ordered_qty) then null
            else cast(s.ordered_qty as integer)
        end                                                                  as ordered_qty,
        case
            when nullif(trim(s.received_qty),'') is null then null
            when cast(cast(trim(s.received_qty) as integer) as text) != trim(s.received_qty) then null
            else cast(s.received_qty as integer)
        end                                                                  as received_qty,
        case
            when nullif(trim(s.unit_cost),'') is null then null
            when trim(s.unit_cost) glob '*[A-Za-z]*' then null
            else cast(s.unit_cost as real)
        end                                                                  as unit_cost,
        upper(trim(s.currency))                                              as currency
    from source s
    left join sku_map sm on lower(trim(s.product_sku)) = lower(trim(sm.raw_value))
    left join warehouse_map wm on lower(trim(s.warehouse_id)) = lower(trim(wm.raw_value))
)

select * from standardized