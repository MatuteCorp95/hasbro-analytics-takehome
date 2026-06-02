with customers as (
    select * from {{ ref('stg_customers') }}
),

ranked as (
    select *,
        row_number() over (
            partition by customer_id
            order by
                case when country is null then 1 else 0 end,
                length(coalesce(country, '~~')),
                customer_name
        ) as rn
    from customers
)

select
    customer_id,
    customer_name,
    channel,
    region,
    country,
    tier,
    is_active,
    parent_customer_id
from ranked
where rn = 1