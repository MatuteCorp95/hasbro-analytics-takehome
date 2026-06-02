with products as (
    select * from {{ ref('stg_products') }}
),

hierarchy_ranked as (
    select *,
        row_number() over (
            partition by product_sku
            order by
                case when effective_end_date is null then 0 else 1 end,
                effective_start_date desc
        ) as rn
    from {{ ref('stg_product_hierarchy') }}
),

hierarchy_current as (
    select * from hierarchy_ranked where rn = 1
),

resolved_products as (
    select
        product_sku,
        coalesce(
            max(case when source_system = 'PLM' then product_name end),
            max(case when source_system = 'ERP' then product_name end)
        ) as product_name,
        coalesce(
            max(case when source_system = 'PLM' then brand_family end),
            max(case when source_system = 'ERP' then brand_family end)
        ) as brand_family_src,
        coalesce(
            max(case when source_system = 'PLM' then franchise end),
            max(case when source_system = 'ERP' then franchise end)
        ) as franchise_src,
        coalesce(
            max(case when source_system = 'PLM' then category end),
            max(case when source_system = 'ERP' then category end)
        ) as category_src,
        coalesce(
            max(case when source_system = 'PLM' then sub_category end),
            max(case when source_system = 'ERP' then sub_category end)
        ) as sub_category_src,
        coalesce(
            max(case when source_system = 'PLM' then age_grade end),
            max(case when source_system = 'ERP' then age_grade end)
        ) as age_grade,
        coalesce(
            max(case when source_system = 'PLM' then lifecycle_status end),
            max(case when source_system = 'ERP' then lifecycle_status end)
        ) as lifecycle_status,
        coalesce(
            max(case when source_system = 'ERP' then unit_cost end),
            max(case when source_system = 'PLM' then unit_cost end)
        ) as unit_cost,
        coalesce(
            max(case when source_system = 'ERP' then list_price end),
            max(case when source_system = 'PLM' then list_price end)
        ) as list_price,
        coalesce(
            max(case when source_system = 'ERP' then case_pack_qty end),
            max(case when source_system = 'PLM' then case_pack_qty end)
        ) as case_pack_qty,
        coalesce(
            max(case when source_system = 'PLM' then launch_date end),
            max(case when source_system = 'ERP' then launch_date end)
        ) as launch_date,
        coalesce(
            max(case when source_system = 'PLM' then discontinue_date end),
            max(case when source_system = 'ERP' then discontinue_date end)
        ) as discontinue_date,
        coalesce(
            max(case when source_system = 'PLM' then unit_of_measure end),
            max(case when source_system = 'ERP' then unit_of_measure end)
        ) as unit_of_measure,
        max(case when source_system = 'PLM' then 1 else 0 end) as is_in_plm,
        max(case when source_system = 'ERP' then 1 else 0 end) as is_in_erp
    from products
    group by product_sku
)

select
    p.product_sku,
    p.product_name,
    coalesce(h.division, 'Unassigned')                            as division,
    coalesce(h.brand_family_std, p.brand_family_src)              as brand_family,
    coalesce(h.franchise_std,    p.franchise_src)                 as franchise,
    coalesce(h.category_std,     p.category_src)                  as category,
    coalesce(h.sub_category_std, p.sub_category_src)              as sub_category,
    p.age_grade,
    coalesce(h.status_std, p.lifecycle_status)                    as lifecycle_status,
    p.unit_cost,
    p.list_price,
    p.case_pack_qty,
    p.unit_of_measure,
    p.launch_date,
    p.discontinue_date,
    p.is_in_plm,
    p.is_in_erp,
    case when h.product_sku is not null then 1 else 0 end         as is_in_hierarchy
from resolved_products p
left join hierarchy_current h on p.product_sku = h.product_sku