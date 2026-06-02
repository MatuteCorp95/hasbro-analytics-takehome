with source as (
    select * from {{ source('raw', 'products_raw') }}
),

sku_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'sku_normalization' and is_active = 1
),

uom_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'uom' and is_active = 1
),

standardized as (
    select
        upper(trim(s.source_system))                                      as source_system,
        coalesce(sm.standard_value, trim(s.product_sku))                  as product_sku,
        trim(s.product_sku)                                               as product_sku_raw,
        nullif(trim(s.alt_sku), '')                                       as alt_sku,
        trim(s.product_name)                                              as product_name,
        trim(s.brand_family)                                              as brand_family,
        trim(s.franchise)                                                 as franchise,
        trim(s.category)                                                  as category,
        nullif(trim(s.sub_category), '')                                  as sub_category,
        nullif(trim(s.age_grade), '')                                     as age_grade,
        lower(trim(s.lifecycle_status))                                   as lifecycle_status,

        case
            when s.launch_date is null or trim(s.launch_date) = '' then null
            when s.launch_date like '__/__/____'
                then substr(s.launch_date,7,4)||'-'||substr(s.launch_date,1,2)||'-'||substr(s.launch_date,4,2)
            else s.launch_date
        end                                                               as launch_date,

        nullif(trim(s.discontinue_date), '')                              as discontinue_date,

        case
            when s.unit_cost is null or trim(s.unit_cost) = '' then null
            when cast(s.unit_cost as real) > 0 then cast(s.unit_cost as real)
            else null
        end                                                               as unit_cost,

        case
            when s.list_price is null or trim(s.list_price) = '' then null
            when cast(s.list_price as real) > 0 then cast(s.list_price as real)
            else null
        end                                                               as list_price,

        case
            when s.case_pack_qty is null or trim(s.case_pack_qty) = '' then null
            when cast(s.case_pack_qty as integer) > 0 then cast(s.case_pack_qty as integer)
            else null
        end                                                               as case_pack_qty,

        coalesce(um.standard_value, upper(trim(s.unit_of_measure)))       as unit_of_measure,
        s.updated_at                                                      as source_updated_at

    from source s
    left join sku_map sm on lower(trim(s.product_sku)) = lower(trim(sm.raw_value))
    left join uom_map um on lower(trim(s.unit_of_measure)) = lower(trim(um.raw_value))
)

select * from standardized