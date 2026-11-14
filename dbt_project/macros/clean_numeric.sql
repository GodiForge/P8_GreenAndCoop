{% macro clean_numeric(field) %}
    case 
        when {{ field }} is null or trim({{ field }}::text) in ('', 'null', 'None', 'NaN', '-/-') then null
        else nullif(regexp_replace(trim({{ field }}::text), '[^0-9.-]', '', 'g'), '')::numeric
    end
{% endmacro %}