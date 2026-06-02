with violations as (
    select
        'fct_sales_orders' as source_model,
        'ship_before_order' as issue_type,
        order_id as record_id,
        'order_date='||coalesce(order_date,'NULL')||', ship_date='||coalesce(ship_date,'NULL') as description
    from {{ ref('fct_sales_orders') }}
    where has_ship_before_order_flag = 1

    union all
    select 'fct_purchase_orders', 'received_before_created', po_id,
        'create_date='||coalesce(po_create_date,'NULL')||', received_date='||coalesce(received_date,'NULL')
    from {{ ref('fct_purchase_orders') }}
    where has_received_before_created_flag = 1

    union all
    select 'fct_purchase_orders', 'overdue_po', po_id,
        'requested='||coalesce(requested_delivery_date,'NULL')||', received='||coalesce(received_date,'NULL')||', status='||coalesce(po_status,'NULL')
    from {{ ref('fct_purchase_orders') }}
    where is_overdue = 1

    union all
    select 'fct_shipments', 'delivery_before_ship', shipment_id,
        'ship_date='||coalesce(ship_date,'NULL')||', delivery_date='||coalesce(delivery_date,'NULL')
    from {{ ref('fct_shipments') }}
    where has_delivery_before_ship_flag = 1

    union all
    select 'fct_shipments', 'late_delivery', shipment_id,
        'actual_transit_days='||coalesce(cast(actual_transit_days as text),'NULL')||', contracted='||coalesce(cast(contracted_transit_days as text),'NULL')
    from {{ ref('fct_shipments') }}
    where is_on_time = 0

    union all
    select 'stg_product_hierarchy', 'scd_overlap', h1.product_sku,
        'overlap: range1=['||h1.effective_start_date||','||coalesce(h1.effective_end_date,'open')||'] range2=['||h2.effective_start_date||','||coalesce(h2.effective_end_date,'open')||']'
    from {{ ref('stg_product_hierarchy') }} h1
    inner join {{ ref('stg_product_hierarchy') }} h2
        on h1.product_sku = h2.product_sku
        and h1.effective_start_date < h2.effective_start_date
        and (h1.effective_end_date is null or h1.effective_end_date >= h2.effective_start_date)

    union all
    select 'stg_shipment_events', 'bad_timestamp', shipment_id||'|'||event_type,
        'raw_timestamp='||coalesce(event_timestamp_raw,'NULL')
    from {{ ref('stg_shipment_events') }}
    where event_timestamp is null and nullif(trim(event_timestamp_raw),'') is not null
)

select * from violations