{{ config(
    materialized='table',
    unique_key='household_id'
) }}

select * from {{ ref('lsa_hmis_csv', 'Affiliation') }}