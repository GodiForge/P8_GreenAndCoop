{{ config(
    materialized='table',
    indexes=[
      {'columns': ['date_id'], 'unique': True, 'type': 'btree'},
      {'columns': ['full_date'], 'unique': True, 'type': 'btree'}
    ],
    post_hook=[
      "ALTER TABLE {{ this }} ADD CONSTRAINT pk_dim_date PRIMARY KEY (date_id);"
    ]
) }}

with date_spine as (
    select distinct 
        cast(recorded_at_utc as date) as full_date
    from {{ ref('int_weather_readings_union') }}
)

select
    cast(to_char(full_date, 'YYYYMMDD') as integer) as date_id,
    full_date,
    extract(year from full_date)::integer as year,
    extract(month from full_date)::integer as month,
    to_char(full_date, 'TMMonth') as month_name,
    extract(day from full_date)::integer as day,
    extract(isodow from full_date)::integer as day_of_week,
    to_char(full_date, 'TMDay') as day_name,
    extract(quarter from full_date)::integer as quarter,
    case 
        when extract(isodow from full_date) in (6, 7) then true 
        else false 
    end as is_weekend
from date_spine
order by full_date