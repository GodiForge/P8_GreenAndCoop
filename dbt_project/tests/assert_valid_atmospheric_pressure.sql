select
    reading_id,
    station_id,
    recorded_at_utc,
    pressure_hpa
from {{ ref('fct_weather_readings') }}
where pressure_hpa is not null
  and (pressure_hpa < 870.0 or pressure_hpa > 1085.0)