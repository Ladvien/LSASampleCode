{{ config(
    materialized='table',
) }}


with lsa_report as (
    select 
        report_end, 
        report_coc, 
        lookback_date
    from {{ ref('lsa_report') }}
),

core as (
    select
        hoh.household_id,
        hoh.personal_id as hoh_id,
        hoh.enrollment_id,
        hoh.project_id,
        p.lsa_project_type,
        hoh.entry_date,
        hoh.move_in_date,
        hx.exit_date,
        min(bn.bed_night_date) as first_bed_night,
        max(bn.bed_night_date) as last_bed_night,
        case 
            when part.hmis_start >= p.operating_start then part.hmis_start
            else p.operating_start 
        end as p_start,
        case 
            when part.hmis_end <= p.operating_end or (part.hmis_end is not null and p.operating_end is null) 
                then part.hmis_end
            when part.hmis_end > p.operating_end or (part.hmis_end is null and p.operating_end is not null) 
                then p.operating_end
            else null 
        end as p_end,
        rpt.lookback_date,
        rpt.report_end
    from {{ source('lsa_staging', 'enrollment') }} hoh
    inner join {{ ref('lsa_report') }} rpt 
        on rpt.report_end >= hoh.entry_date 
        and rpt.report_coc = hoh.enrollment_coc
    inner join (
        select 
            hp.project_id,
            case 
                when hp.project_type = 13 and hp.rrh_sub_type = 1 then 15 
                else hp.project_type 
            end as lsa_project_type,
            hp.operating_start_date as operating_start,
            case 
                when hp.operating_end_date <= cd.cohort_end then hp.operating_end_date 
                else null 
            end as operating_end
        from {{ source('lsa_staging', 'project') }} hp
        inner join {{ source('lsa_staging', 'organization') }} ho 
            on ho.organization_id = hp.organization_id
        inner join {{ ref('tlsa_cohort_dates') }} cd 
            on cd.cohort = 1
        where hp.date_deleted is null
          and hp.continuum_project = 1
          and ho.victim_service_provider = 0
          and hp.project_type in (0, 1, 2, 3, 8, 13)
          and (hp.project_type <> 13 or hp.rrh_sub_type in (1, 2))
          and hp.operating_start_date <= cd.cohort_end
          and (hp.operating_end_date is null 
               or (hp.operating_end_date > hp.operating_start_date 
                   and hp.operating_end_date > cd.lookback_date))
    ) p on p.project_id = hoh.project_id
    left join {{ source('lsa_staging', 'exit') }} hx 
        on hx.enrollment_id = hoh.enrollment_id
        and (hx.exit_date <= p.operating_end or p.operating_end is null)
        and hx.date_deleted is null
    left join {{ source('lsa_staging', 'services') }} svc 
        on svc.enrollment_id = hoh.enrollment_id
        and svc.record_type = 200
        and svc.date_deleted is null
    where hoh.date_deleted is null
      and hoh.relationship_to_hoh = 1
      and (hoh.entry_date < p.operating_end or p.operating_end is null)
),

final as (
    select
        core.household_id,
        core.hoh_id,
        core.enrollment_id,
        core.project_id,
        core.lsa_project_type,
        case 
            when core.lsa_project_type = 1 then core.first_bed_night
            when core.entry_date >= core.p_start then core.entry_date
            else core.p_start 
        end as entry_date,
        case 
            when core.move_in_date is null
                or core.move_in_date > core.report_end 
                or core.lsa_project_type not in (3, 13, 15) 
                or core.move_in_date < core.entry_date 
                or core.move_in_date >= core.p_end 
                or core.move_in_date > core.exit_date
                or (core.move_in_date = core.exit_date and core.lsa_project_type = 3)
            then null
            when core.move_in_date >= core.p_start then core.move_in_date
            else core.p_start 
        end as move_in_date,
        case 
            when core.lsa_project_type = 1 and core.last_bed_night = core.report_end then null
            when core.lsa_project_type = 1 and core.exit_date < core.report_end then core.last_bed_night + interval '1 day'
            when core.last_bed_night + interval '90 days' <= core.report_end then core.last_bed_night + interval '1 day'
            when core.lsa_project_type in (13, 15) and core.move_in_date = core.exit_date 
                and core.exit_date = core.report_end then null
            when core.lsa_project_type in (13, 15) and core.move_in_date = core.exit_date 
                and core.exit_date < core.report_end then core.exit_date + interval '1 day'
            when core.p_end is not null and (core.exit_date is null or core.exit_date >= core.p_end) then core.p_end   
            else core.exit_date 
        end as exit_date,
        core.last_bed_night,
        '3.3.1' as step
    from core
    where core.lsa_project_type <> 1 or core.last_bed_night is not null
)

select * from final

