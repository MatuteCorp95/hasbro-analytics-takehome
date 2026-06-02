with source as (
    select * from {{ source('raw', 'shipment_events_raw') }}
),

standardized as (
    select
        trim(s.shipment_id)                                                  as shipment_id,
        case
            when nullif(trim(s.event_timestamp),'') is null then null
            when s.event_timestamp glob '____-__-__ __:__*' then trim(s.event_timestamp)
            else null
        end                                                                  as event_timestamp,
        trim(s.event_timestamp)                                              as event_timestamp_raw,
        upper(trim(s.event_type))                                            as event_type,
        nullif(trim(s.event_location),'')                                    as event_location,
        lower(trim(s.event_status))                                          as event_status
    from source s
)

select * from standardized