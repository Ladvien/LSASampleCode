{{ config(
    materialized='table'
) }}

-- Using variables defined in dbt_project.yml
SELECT
    (EXTRACT(YEAR FROM CURRENT_DATE)::INT % 10) * 100000000 + CAST(TO_CHAR(CURRENT_DATE, 'MMDDHH24MI') AS INT) AS report_id,
    '{{ var("lsa_config")["report_dates"]["start"] }}'::DATE AS report_start_date,
    '{{ var("lsa_config")["report_dates"]["end"] }}'::DATE AS report_end_date,
    '{{ var("lsa_config")["report_coc"] }}' AS report_coc,
    '{{ var("lsa_config")["software_vendor"] }}' AS software_vendor,
    '{{ var("lsa_config")["software_name"] }}' AS software_name,
    '{{ var("lsa_config")["vendor_contact"] }}' AS vendor_contact,
    '{{ var("lsa_config")["vendor_email"] }}' AS vendor_email,
    {{ var("lsa_config")["lsa_scope"] }} AS lsa_scope,
    (DATE '{{ var("lsa_config")["report_dates"]["start"] }}' - INTERVAL '7 years')::DATE AS lookback_date
