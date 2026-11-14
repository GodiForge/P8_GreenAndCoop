with ic as (
    select
        recorded_at_utc,
        station_id,
        temperature_celsius,
        humidity_percentage,
        pressure_hpa,
        wind_speed_kmh,
        wind_gust_kmh,
        rainfall_1h_mm,
        wind_direction_deg,
        data_source
    from {{ ref('stg_infoclimat_readings') }}
),
wu_mad as (
    select
        recorded_at_utc,
        station_id,
        temperature_celsius,
        humidity_percentage,
        pressure_hpa,
        wind_speed_kmh,
        wind_gust_kmh,
        rainfall_1h_mm,
        wind_direction_deg,
        data_source
    from {{ ref('stg_wu_la_madeleine') }}
),
wu_icht as (
    select
        recorded_at_utc,
        station_id,
        temperature_celsius,
        humidity_percentage,
        pressure_hpa,
        wind_speed_kmh,
        wind_gust_kmh,
        rainfall_1h_mm,
        wind_direction_deg,
        data_source
    from {{ ref('stg_wu_ichtegem') }}
),
all_readings as (
    select * from ic
    union all
    select * from wu_mad
    union all
    select * from wu_icht
),
ranked_readings as (
    select
        recorded_at_utc,
        station_id,
        temperature_celsius,
        humidity_percentage,
        pressure_hpa,
        wind_speed_kmh,
        wind_gust_kmh,
        coalesce(rainfall_1h_mm, 0.0) as rainfall_1h_mm,
        wind_direction_deg,
        data_source,
        row_number() over (
            partition by station_id, recorded_at_utc 
            order by temperature_celsius is not null desc
        ) as row_num
    from all_readings
    where recorded_at_utc is not null
      and station_id is not null
)
select
    recorded_at_utc,
    station_id,
    temperature_celsius,
    humidity_percentage,
    pressure_hpa,
    wind_speed_kmh,
    wind_gust_kmh,
    rainfall_1h_mm,
    wind_direction_deg,
    data_source
from ranked_readings
where row_num = 1