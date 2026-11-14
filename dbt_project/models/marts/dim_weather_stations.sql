{{ config(
    materialized='table',
    indexes=[
      {'columns': ['station_id'], 'unique': True, 'type': 'btree'}
    ],
    post_hook=[
      "ALTER TABLE {{ this }} ADD CONSTRAINT pk_dim_weather_stations PRIMARY KEY (station_id);"
    ]
) }}

select
    station_id,
    station_name,
    network_name,
    city,
    country,
    latitude,
    longitude,
    elevation_meters,
    hardware,
    software,
    is_amateur,
    current_timestamp as loaded_at
from {{ ref('int_weather_stations_union') }}