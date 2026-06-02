with source as (
    select * from {{ source('raw', 'inventory_snapshots_raw') }}
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

uom_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'uom' and is_active = 1
),

standardized as (
    select
        nullif(trim(s.snapshot_date),'')                                     as snapshot_date,
        coalesce(wm.standard_value, trim(s.warehouse_id))                    as warehouse_id,
        trim(s.warehouse_id)                                                 as warehouse_id_raw,
        coalesce(sm.standard_value, trim(s.product_sku))                     as product_sku,
        trim(s.product_sku)                                                  as product_sku_raw,
        case
            when nullif(trim(s.on_hand_qty),'') is null then null
            when cast(cast(trim(s.on_hand_qty) as integer) as text) != trim(s.on_hand_qty) then null
            else cast(s.on_hand_qty as integer)
        end                                                                  as on_hand_qty,
        case
            when nullif(trim(s.allocated_qty),'') is null then null
            when cast(cast(trim(s.allocated_qty) as integer) as text) != trim(s.allocated_qty) then null
            else cast(s.allocated_qty as integer)
        end                                                                  as allocated_qty,
        case
            when nullif(trim(s.available_qty),'') is null then null
            when cast(cast(trim(s.available_qty) as integer) as text) != trim(s.available_qty) then null
            else cast(s.available_qty as integer)
        end                                                                  as available_qty,
        case
            when nullif(trim(s.in_transit_qty),'') is null then null
            when cast(cast(trim(s.in_transit_qty) as integer) as text) != trim(s.in_transit_qty) then null
            else cast(s.in_transit_qty as integer)
        end                                                                  as in_transit_qty,
        case
            when nullif(trim(s.safety_stock_qty),'') is null then null
            when cast(cast(trim(s.safety_stock_qty) as integer) as text) != trim(s.safety_stock_qty) then null
            else cast(s.safety_stock_qty as integer)
        end                                                                  as safety_stock_qty,
        coalesce(um.standard_value, upper(trim(s.unit_of_measure)))          as unit_of_measure,
        lower(trim(s.inventory_status))                                      as inventory_status
    from source s
    left join sku_map sm on lower(trim(s.product_sku)) = lower(trim(sm.raw_value))
    left join warehouse_map wm on lower(trim(s.warehouse_id)) = lower(trim(wm.raw_value))
    left join uom_map um on lower(trim(s.unit_of_measure)) = lower(trim(um.raw_value))
)

select * from standardized