with orphans as (
    select 'fct_sales_orders' as source_model, 'unknown_customer' as issue_type, order_id as record_id, customer_id as offending_value, 'Customer ID not found in dim_customer' as description
    from {{ ref('fct_sales_orders') }} where is_known_customer = 0

    union all
    select 'fct_sales_orders', 'unknown_product', order_id, product_sku, 'Product SKU not found in dim_product'
    from {{ ref('fct_sales_orders') }} where is_known_product = 0

    union all
    select 'fct_purchase_orders', 'unknown_supplier', po_id, supplier_id, 'Supplier ID not found in dim_supplier'
    from {{ ref('fct_purchase_orders') }} where is_known_supplier = 0

    union all
    select 'fct_purchase_orders', 'unknown_product', po_id, product_sku, 'Product SKU not found in dim_product'
    from {{ ref('fct_purchase_orders') }} where is_known_product = 0

    union all
    select 'fct_purchase_orders', 'unknown_warehouse', po_id, warehouse_id, 'Warehouse ID not found in dim_warehouse'
    from {{ ref('fct_purchase_orders') }} where is_known_warehouse = 0

    union all
    select 'fct_shipments', 'unknown_order', shipment_id, order_id, 'Order ID not found in fct_sales_orders'
    from {{ ref('fct_shipments') }} where is_known_order = 0

    union all
    select 'fct_marketing_performance', 'unknown_campaign', cast(performance_date as text)||'|'||campaign_id, campaign_id, 'Campaign ID not found in stg_marketing_campaigns'
    from {{ ref('fct_marketing_performance') }} where is_known_campaign = 0

    union all
    select 'stg_marketing_campaigns', 'unknown_product', c.campaign_id, c.product_sku, 'Product SKU not found in dim_product'
    from {{ ref('stg_marketing_campaigns') }} c
    where c.product_sku is not null
      and not exists (select 1 from {{ ref('dim_product') }} d where d.product_sku = c.product_sku)

    union all
    select 'stg_product_hierarchy', 'hierarchy_without_product', h.product_sku, h.product_sku, 'Product SKU exists in hierarchy but not in product master'
    from {{ ref('stg_product_hierarchy') }} h
    where not exists (select 1 from {{ ref('dim_product') }} d where d.product_sku = h.product_sku)
)

select * from orphans