with violations as (
    select
        'fct_inventory_snapshots' as source_model,
        'negative_on_hand' as issue_type,
        warehouse_id||'|'||product_sku||'|'||snapshot_date as record_id,
        'on_hand_qty='||cast(on_hand_qty as text) as description
    from {{ ref('fct_inventory_snapshots') }}
    where has_negative_on_hand_flag = 1

    union all
    select 'fct_inventory_snapshots', 'oversold', warehouse_id||'|'||product_sku||'|'||snapshot_date,
        'allocated > on_hand'
    from {{ ref('fct_inventory_snapshots') }}
    where is_oversold = 1

    union all
    select 'fct_inventory_snapshots', 'stockout', warehouse_id||'|'||product_sku||'|'||snapshot_date,
        'available_qty<=0 and status!=prelaunch'
    from {{ ref('fct_inventory_snapshots') }}
    where is_stockout = 1

    union all
    select 'fct_inventory_snapshots', 'below_safety_stock', warehouse_id||'|'||product_sku||'|'||snapshot_date,
        'available<safety_stock and status!=prelaunch'
    from {{ ref('fct_inventory_snapshots') }}
    where is_below_safety_stock = 1

    union all
    select 'fct_retail_pos', 'negative_pos_units', retailer_id||'|'||product_sku||'|'||week_start_date,
        'pos_units='||cast(pos_units as text)
    from {{ ref('fct_retail_pos') }}
    where has_negative_pos_flag = 1

    union all
    select 'fct_retail_pos', 'negative_retail_on_hand', retailer_id||'|'||product_sku||'|'||week_start_date,
        'on_hand_units='||cast(on_hand_units as text)
    from {{ ref('fct_retail_pos') }}
    where has_negative_on_hand_flag = 1

    union all
    select 'fct_marketing_performance', 'negative_clicks', campaign_id||'|'||performance_date,
        'clicks='||cast(clicks as text)
    from {{ ref('fct_marketing_performance') }}
    where has_negative_clicks_flag = 1

    union all
    select 'fct_sales_orders', 'invalid_ordered_units', order_id,
        'ordered_units was non-numeric in source (now NULL)'
    from {{ ref('fct_sales_orders') }}
    where fulfillment_status = 'units_unknown'

    union all
    select 'fct_shipments', 'missing_tracking', shipment_id,
        'tracking_number is null'
    from {{ ref('fct_shipments') }}
    where is_missing_tracking = 1
)

select * from violations