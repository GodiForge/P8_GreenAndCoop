with raw_data as (
    select stations from {{ source('raw_weather', 'infoclimat_raw') }}
),
stations_expanded as (
    select jsonb_array_elements(stations::jsonb) as s
    from raw_data
    where stations is not null
)
select distinct
    s->>'id' as station_id,
    s->>'name' as station_name,
    cast(s->>'latitude' as numeric) as latitude,
    cast(s->>'longitude' as numeric) as longitude,
    cast(s->>'elevation' as numeric) as elevation_meters,
    'InfoClimat' as network_name,
    case 
        when s->>'id' = '07015' then 'Lille-Lesquin'
        when s->>'id' = '00052' then U&'Armenti\00e8res'
        when s->>'id' = '000R5' then 'Bergues'
        when s->>'id' = 'STATIC0010' then 'Hazebrouck'
        else s->>'name'
    end as city,
    'France' as country,
    U&'M\00e9t\00e9o-France / InfoClimat' as hardware,
    'InfoClimat API JSON' as software,
    false as is_amateur
from stations_expanded
where s->>'id' is not null