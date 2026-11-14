select
    reading_id,
    station_id,
    recorded_at_utc,
    temperature_celsius
from {{ ref('fct_weather_readings') }}
where temperature_celsius is not null
  and (temperature_celsius < -50.0 or temperature_celsius > 60.0)