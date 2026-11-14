with infoclimat_stations as (
    select
        station_id,
        station_name,
        latitude,
        longitude,
        elevation_meters,
        network_name,
        city,
        country,
        hardware,
        software,
        is_amateur
    from {{ ref('stg_infoclimat_stations') }}
),
amateur_stations as (
    select
        'ILAMAD25' as station_id,
        'La Madeleine' as station_name,
        50.659::numeric as latitude,
        3.070::numeric as longitude,
        23.0::numeric as elevation_meters,
        'Weather Underground' as network_name,
        'La Madeleine' as city,
        'France' as country,
        'other' as hardware,
        'EasyWeatherPro_V5.1.6' as software,
        true as is_amateur
    union all
    select
        'IICHTE19' as station_id,
        'WeerstationBS' as station_name,
        51.092::numeric as latitude,
        2.999::numeric as longitude,
        15.0::numeric as elevation_meters,
        'Weather Underground' as network_name,
        'Ichtegem' as city,
        'Belgique' as country,
        'other' as hardware,
        'EasyWeatherV1.6.6' as software,
        true as is_amateur
)
select * from infoclimat_stations
union all
select * from amateur_stations