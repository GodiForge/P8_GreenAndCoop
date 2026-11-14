with raw_data as (
    select hourly from {{ source('raw_weather', 'infoclimat_raw') }}
),
hourly_stations as (
    select key as station_id, value as readings_array
    from raw_data,
    jsonb_each(hourly::jsonb)
    where key not like '\_%'
),
readings_expanded as (
    select 
        station_id,
        jsonb_array_elements(readings_array) as r
    from hourly_stations
)
select
    cast(r->>'dh_utc' as timestamp) as recorded_at_utc,
    station_id,
    {{ clean_numeric("r->>'temperature'") }} as temperature_celsius,
    {{ clean_numeric("r->>'humidite'") }} as humidity_percentage,
    {{ clean_numeric("r->>'pression'") }} as pressure_hpa,
    {{ clean_numeric("r->>'vent_moyen'") }} as wind_speed_kmh,
    {{ clean_numeric("r->>'vent_rafales'") }} as wind_gust_kmh,
    {{ clean_numeric("r->>'pluie_1h'") }} as rainfall_1h_mm,
    {{ clean_numeric("r->>'vent_direction'") }} as wind_direction_deg,
    'InfoClimat' as data_source
from readings_expanded
where r->>'dh_utc' is not null