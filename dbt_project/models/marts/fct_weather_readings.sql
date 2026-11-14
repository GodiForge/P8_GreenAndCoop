{{ config(
    materialized='table',
    indexes=[
      {'columns': ['reading_id'], 'unique': True, 'type': 'btree'},
      {'columns': ['station_id'], 'type': 'btree'},
      {'columns': ['date_id'], 'type': 'btree'},
      {'columns': ['recorded_at_utc'], 'type': 'btree'},
      {'columns': ['station_id', 'recorded_at_utc'], 'type': 'btree'}
    ],
    post_hook=[
      "ALTER TABLE {{ this }} ADD CONSTRAINT pk_fct_weather_readings PRIMARY KEY (reading_id);",
      "ALTER TABLE {{ this }} ADD CONSTRAINT fk_fct_readings_station FOREIGN KEY (station_id) REFERENCES {{ ref('dim_weather_stations') }} (station_id) ON DELETE RESTRICT;",
      "ALTER TABLE {{ this }} ADD CONSTRAINT fk_fct_readings_date FOREIGN KEY (date_id) REFERENCES {{ ref('dim_date') }} (date_id) ON DELETE RESTRICT;",
      "ALTER TABLE {{ this }} ADD CONSTRAINT chk_temperature_range CHECK (temperature_celsius IS NULL OR (temperature_celsius >= -50.0 AND temperature_celsius <= 60.0));",
      "ALTER TABLE {{ this }} ADD CONSTRAINT chk_humidity_range CHECK (humidity_percentage IS NULL OR (humidity_percentage >= 0.0 AND humidity_percentage <= 100.0));",
      "ALTER TABLE {{ this }} ADD CONSTRAINT chk_wind_direction CHECK (wind_direction_deg IS NULL OR (wind_direction_deg >= 0.0 AND wind_direction_deg <= 360.0));"
    ]
) }}

with readings as (
    select * from {{ ref('int_weather_readings_union') }}
)

select
    md5(r.station_id || '_' || to_char(r.recorded_at_utc, 'YYYY-MM-DD"T"HH24:MI:SS')) as reading_id,
    cast(to_char(r.recorded_at_utc, 'YYYYMMDD') as integer) as date_id,
    r.station_id,
    r.recorded_at_utc,
    r.temperature_celsius,
    r.humidity_percentage,
    r.pressure_hpa,
    r.wind_speed_kmh,
    r.wind_gust_kmh,
    r.rainfall_1h_mm,
    r.wind_direction_deg,
    r.data_source,
    current_timestamp as ingested_at_utc
from readings r