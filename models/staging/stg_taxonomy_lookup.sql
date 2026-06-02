with source as (
    select * from {{ source('raw', 'taxonomy_lookup_raw') }}
),

source_taxonomy as (
    select
        lower(trim(mapping_type))                                  as mapping_type,
        trim(raw_value)                                            as raw_value,
        trim(standard_value)                                       as standard_value,
        lower(trim(domain))                                        as domain,
        case when upper(trim(active_flag)) = 'Y' then 1 else 0 end as is_active,
        nullif(trim(effective_start_date), '')                     as effective_start_date,
        nullif(trim(effective_end_date), '')                       as effective_end_date,
        'source_taxonomy'                                          as mapping_source
    from source
    where raw_value is not null
      and raw_value != ''
      and standard_value is not null
      and standard_value != ''
),

-- Mappings observed in the data but missing from the source taxonomy.
-- Flagged for review with the data governance team; tagged as 'discovered_gap'
-- so they're auditable and removable once the source taxonomy is updated.
discovered_gaps as (
    select 'sku_normalization' as mapping_type, 'sku1007' as raw_value, 
        'SKU-1007' as standard_value, 'product' as domain, 1 as is_active, 
        '2024-07-01' as effective_start_date, null as effective_end_date, 
        'discovered_gap' as mapping_source
    union all
    select 'country', 'United States', 'US', 'enterprise', 1, '2024-01-01', null, 'discovered_gap'
    union all
    select 'country', 'Poland', 'PL', 'enterprise', 1, '2024-01-01', null, 'discovered_gap'
    union all
    select 'region', 'Europe', 'EMEA', 'enterprise', 1, '2024-01-01', null, 'discovered_gap'
)

select * from source_taxonomy
union all
select * from discovered_gaps