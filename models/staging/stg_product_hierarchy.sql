with source as (
    select * from {{ source('raw', 'product_hierarchy_raw') }}
),

sku_map as (
    select raw_value, standard_value
    from {{ ref('stg_taxonomy_lookup') }}
    where mapping_type = 'sku_normalization' and is_active = 1
),

standardized as (
    select
        coalesce(sm.standard_value, trim(s.product_sku))                     as product_sku,
        trim(s.product_sku)                                                  as product_sku_raw,
        nullif(trim(s.effective_start_date),'')                              as effective_start_date,
        nullif(trim(s.effective_end_date),'')                                as effective_end_date,
        nullif(trim(s.division),'')                                          as division,
        nullif(trim(s.brand_family_std),'')                                  as brand_family_std,
        nullif(trim(s.franchise_std),'')                                     as franchise_std,
        nullif(trim(s.category_std),'')                                      as category_std,
        nullif(trim(s.sub_category_std),'')                                  as sub_category_std,
        lower(nullif(trim(s.status_std),''))                                 as status_std
    from source s
    left join sku_map sm on lower(trim(s.product_sku)) = lower(trim(sm.raw_value))
)

select * from standardized