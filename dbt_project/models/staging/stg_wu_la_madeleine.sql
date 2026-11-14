with raw_source as (
    select * from {{ source('raw_weather', 'wu_lamadeleine_raw') }}
)
select
    cast(('2024-10-01 ' || trim("Time")) as timestamp) as recorded_at_utc,
    'ILAMAD25' as station_id,
    round((({{ clean_numeric('"Temperature"') }} - 32.0) * 5.0 / 9.0)::numeric, 1) as temperature_celsius,
    {{ clean_numeric('"Humidity"') }} as humidity_percentage,
    round(({{ clean_numeric('"Pressure"') }} * 33.8639)::numeric, 1) as pressure_hpa,
    round(({{ clean_numeric('"Speed"') }} * 1.60934)::numeric, 1) as wind_speed_kmh,
    round(({{ clean_numeric('"Gust"') }} * 1.60934)::numeric, 1) as wind_gust_kmh,
    round(({{ clean_numeric('"Precip__Rate_"') }} * 25.4)::numeric, 1) as rainfall_1h_mm,
    {{ clean_numeric('"Wind"') }} as wind_direction_deg,
    'Weather Underground' as data_source
from raw_source
where "Time" is not null
  and trim("Time") like '%:%'