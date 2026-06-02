with source as (
    select * from {{ source('raw', 'taxonomy_lookup_raw') }}
),

cleaned as (
    select
        lower(trim(mapping_type))                                  as mapping_type,
        trim(raw_value)                                            as raw_value,
        trim(standard_value)                                       as standard_value,
        lower(trim(domain))                                        as domain,
        case when upper(trim(active_flag)) = 'Y' then 1 else 0 end as is_active,
        nullif(trim(effective_start_date), '')                     as effective_start_date,
        nullif(trim(effective_end_date), '')                       as effective_end_date
    from source
    where raw_value is not null
      and raw_value != ''
      and standard_value is not null
      and standard_value != ''
)

select * from cleaned