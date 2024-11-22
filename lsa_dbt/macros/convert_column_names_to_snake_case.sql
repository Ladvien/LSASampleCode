{% macro convert_column_names_to_snake_case(relation, target_schema) %}

{{
    config(
        materialized='view',
        schema=target_schema,
    )
}}    
    {% set columns = adapter.get_columns_in_relation(relation) %}
    {% set re = modules.re %}

    {% set query  %}
    SELECT
    {% for column in columns %}
        "{{ column.column }}" AS {{ re.sub("(?<!^)([A-Z][a-z]|(?<=[a-z])[^a-z]|(?<=[A-Z])[0-9_])", "_\g<1>", column.column).lower() }}
    {%- if not loop.last %},{% endif -%}
    {% endfor %}
    FROM {{ relation }}
    {% endset %}

    {{ return(query) }}

{% endmacro %}
