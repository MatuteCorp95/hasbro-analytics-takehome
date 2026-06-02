with source as (
    select * from {{ source('raw', 'retail_pos_raw') }}
),

sku_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'sku_normalization' and is_active = 1
),

standardized as (
    select
        trim(s.retailer_id)                                                  as retailer_id,
        case
            when s.week_start_date like '____/__/__'
                then replace(s.week_start_date, '/', '-')
            else nullif(trim(s.week_start_date),'')
        end                                                                  as week_start_date,
        coalesce(sm.standard_value, trim(s.product_sku))                     as product_sku,
        trim(s.product_sku)                                                  as product_sku_raw,
        case
            when nullif(trim(s.store_count),'') is null then null
            when cast(cast(trim(s.store_count) as integer) as text) != trim(s.store_count) then null
            else cast(s.store_count as integer)
        end                                                                  as store_count,
        case
            when nullif(trim(s.pos_units),'') is null then null
            when cast(cast(trim(s.pos_units) as integer) as text) != trim(s.pos_units) then null
            else cast(s.pos_units as integer)
        end                                                                  as pos_units,
        case
            when nullif(trim(s.pos_sales),'') is null then null
            when trim(s.pos_sales) glob '*[A-Za-z]*' then null
            else cast(s.pos_sales as real)
        end                                                                  as pos_sales,
        case
            when nullif(trim(s.on_hand_units),'') is null then null
            when cast(cast(trim(s.on_hand_units) as integer) as text) != trim(s.on_hand_units) then null
            else cast(s.on_hand_units as integer)
        end                                                                  as on_hand_units,
        case
            when nullif(trim(s.on_order_units),'') is null then null
            when cast(cast(trim(s.on_order_units) as integer) as text) != trim(s.on_order_units) then null
            else cast(s.on_order_units as integer)
        end                                                                  as on_order_units,
        upper(trim(s.currency))                                              as currency,
        nullif(trim(s.feed_date),'')                                         as feed_date
    from source s
    left join sku_map sm on lower(trim(s.product_sku)) = lower(trim(sm.raw_value))
)

select * from standardized