select
    reading_id,
    station_id,
    recorded_at_utc
from {{ ref('fct_weather_readings') }}
where recorded_at_utc > (current_timestamp + interval '1 day')