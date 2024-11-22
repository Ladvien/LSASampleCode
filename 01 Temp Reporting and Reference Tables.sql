/*
LSA FY2024 Sample Code 
Name:  01 Temp Reporting and Reference Tables.sql

FY2024 Changes
	
	-Extend ref_Calendar through 9/30/2025
	-Add ch_Include_exit, ch_Exclude_exit, ch_Episodes_exit, and sys_TimePadded_exit


	(Detailed revision history maintained at https://github.com/HMIS/LSASampleCode)

It is not necessary to execute this code every time the LSA is run -- only 
if/when there are changes to it.   It drops (if tables exist) and creates
the following temp reporting tables:

	tlsa_CohortDates - based on ReportStart and ReportEnd, all cohorts and dates used in the LSA
	tlsa_HHID - 'master' table of HMIS HouseholdIDs active in continuum ES/SH/TH/RRH/PSH projects 
			between LookbackDate (ReportStart - 7 years)  and ReportEnd.  Used to store adjusted move-in 
			and exit dates, household types, and other frequently-referenced data 
	tlsa_Enrollment - a 'master' table of enrollments associated with the HouseholdIDs in tlsa_HHID
			with enrollment ages and other frequently-referenced data

	tlsa_Person - a person-level pre-cursor to LSAPerson / people active in report period
		ch_Exclude - dates in TH or housed in RRH/PSH; used for LSAPerson chronic homelessness determination
		ch_Include - dates in ES/SH or on the street; used for LSAPerson chronic homelessness determination
		ch_Episodes - episodes of ES/SH/Street time constructed from ch_Include for chronic homelessness determination
	tlsa_Household - a household-level precursor to LSAHousehold / households active in report period
		sys_TimePadded - used to identify households' last inactive date for SystemPath 
		sys_Time - used to count dates in ES/SH, TH, RRH/PSH but not housed, housed in RRH/PSH, and ES/SH/StreetDates
	tlsa_Exit - household-level precursor to LSAExit / households with system exits in exit cohort periods
		ch_Exclude_exit - dates in TH or housed in RRH/PSH; used for LSAExit chronic homelessness determination
		ch_Include_exit - dates in ES/SH or on the street; used for LSAExit chronic homelessness determination
		ch_Episodes_exit - episodes of ES/SH/Street time constructed from ch_Include_exit for LSAExit chronic homelessness determination
		sys_TimePadded_exit - used to identify households' last inactive date for SystemPath 
	tlsa_ExitHoHAdult - used as the basis for determining chronic homelessness for LSAExit
	tlsa_AveragePops - used to identify households in various populations for average # of days in section 8 
		based on LSAHousehold and LSAExit.
	tlsa_CountPops - used to identify people/households in various populations for AHAR counts in section 9.

This script also drops (if tables exist), creates, and populates the following 
reference tables used in the sample code:  
	ref_Calendar - table of dates between 10/1/2012 and 9/30/2025  
	ref_RowValues - required combinations of Cohort, Universe, and SystemPath values for each ReportRow in LSACalculated
	ref_RowPopulations - the populations required for each ReportRow in LSACalculated
	ref_PopHHTypes - the household types associated with each population 
	
*/

if object_id ('tlsa_CohortDates') is not null drop table tlsa_CohortDates
	
create table tlsa_CohortDates (
	Cohort int
	, CohortStart date
	, CohortEnd date
	, LookbackDate date
	, ReportID int
	, constraint pk_tlsa_CohortDates primary key clustered (Cohort)
	)
	;

if object_id ('tlsa_HHID') is not NULL drop table tlsa_HHID 

create table tlsa_HHID (
	 HouseholdID nvarchar(32)
	, HoHID nvarchar(32)
	, EnrollmentID nvarchar(32)
	, ProjectID nvarchar(32)
	, LSAProjectType int
	, EntryDate date
	, MoveInDate date
	, ExitDate date
	, LastBednight date
	, EntryHHType int
	, ActiveHHType int
	, Exit1HHType int
	, Exit2HHType int
	, ExitDest int
	, Active bit default 0
	, AHAR bit default 0
	, PITOctober bit default 0
	, PITJanuary bit default 0
	, PITApril bit default 0
	, PITJuly bit default 0
	, ExitCohort int
	, HHChronic int default 0
	, HHVet int default 0
	, HHDisability int default 0
	, HHFleeingDV int default 0
	, HHAdultAge int default 0
	, HHParent int default 0
	, AC3Plus int default 0
	, Step nvarchar(10) not NULL
	, constraint pk_tlsa_HHID primary key clustered (HouseholdID)
	)
	;
	create index ix__tlsa_HHID_Active_HHAdultAge on tlsa_HHID (Active, HHAdultAge) INCLUDE (HoHID, ActiveHHType)
	create index ix_tlsa_HHID_HoHID_ActiveHHType on tlsa_HHID (HoHID, ActiveHHType) include (EntryDate, EnrollmentID)
	create index ix_tlsa_HHID_ActiveHHType_AHAR_HHAdultAge on tlsa_HHID (ActiveHHType, AHAR, HHAdultAge)

if object_id ('tlsa_Enrollment') is not NULL drop table tlsa_Enrollment 

create table tlsa_Enrollment (
	EnrollmentID nvarchar(32)
	, PersonalID nvarchar(32)
	, HouseholdID nvarchar(32)
	, RelationshipToHoH int
	, ProjectID nvarchar(32)
	, LSAProjectType int
	, EntryDate date
	, MoveInDate date
	, ExitDate date
	, LastBednight date
	, EntryAge int
	, ActiveAge int
	, Exit1Age int
	, Exit2Age int
	, DisabilityStatus int
	, DVStatus int
	, Active bit default 0
	, AHAR bit default 0
	, PITOctober bit default 0
	, PITJanuary bit default 0
	, PITApril bit default 0
	, PITJuly bit default 0
	, CH bit default 0
	, HIV bit default 0
	, SMI bit default 0
	, SUD bit default 0
	, Step nvarchar(10) not NULL
	, constraint pk_tlsa_Enrollment primary key clustered (EnrollmentID)
	)

	create index ix_tlsa_Enrollment_AHAR on tlsa_Enrollment (AHAR) include (PersonalID)
--create index ix_tlsa_Enrollment_PersonalID_AHAR on tlsa_Enrollment (PersonalID, AHAR)
--create index ix_tlsa_Enrollment_Active on tlsa_Enrollment (Active) include (RelationshipToHoH, ProjectID, EntryDate, ActiveAge)

if object_id ('tlsa_Person') is not NULL drop table tlsa_Person

create table tlsa_Person (
-- client-level precursor to aggregate lsa_Person (LSAPerson.csv)
	PersonalID nvarchar(32) not NULL,
	HoHAdult int,
	CHStart date,
	LastActive date,
	Gender int,
	RaceEthnicity int,
	VetStatus int,
	DisabilityStatus int,
	CHTime int,
	CHTimeStatus int,
	DVStatus int,
	ESTAgeMin int default -1,
	ESTAgeMax int default -1,
	HHTypeEST int default -1,
	HoHEST int default -1,
	AdultEST int default -1,
	AHARAdultEST int default -1,
	HHChronicEST int default -1,
	HHVetEST int default -1,
	HHDisabilityEST int default -1,
	HHFleeingDVEST int default -1,
	HHAdultAgeAOEST int default -1,
	HHAdultAgeACEST int default -1,
	HHParentEST int default -1,
	AC3PlusEST int default -1,
	AHAREST int default -1,
	AHARHoHEST int default -1,
	RRHAgeMin int default -1,
	RRHAgeMax int default -1,
	HHTypeRRH int default -1,
	HoHRRH int default -1,
	AdultRRH int default -1,
	AHARAdultRRH int default -1,
	HHChronicRRH int default -1,
	HHVetRRH int default -1,
	HHDisabilityRRH int default -1,
	HHFleeingDVRRH int default -1,
	HHAdultAgeAORRH int default -1,
	HHAdultAgeACRRH int default -1,
	HHParentRRH int default -1,
	AC3PlusRRH int default -1,
	AHARRRH int default -1,
	AHARHoHRRH int default -1,
	PSHAgeMin int default -1,
	PSHAgeMax int default -1,
	HHTypePSH int default -1,
	HoHPSH int default -1,
	AdultPSH int default -1,
	AHARAdultPSH int default -1,
	HHChronicPSH int default -1,
	HHVetPSH int default -1,
	HHDisabilityPSH int default -1,
	HHFleeingDVPSH int default -1,
	HHAdultAgeAOPSH int default -1,
	HHAdultAgeACPSH int default -1,
	HHParentPSH int default -1,
	AC3PlusPSH int default -1,
	AHARPSH int default -1,
	AHARHoHPSH int default -1,	
	RRHSOAgeMin int default -1,
	RRHSOAgeMax int default -1,
	HHTypeRRHSONoMI int default -1,
	HHTypeRRHSOMI int default -1,
	HHTypeES int default -1,
	HHTypeSH int default -1,
	HHTypeTH int default -1,
	HIV int default -1,
	SMI int default -1,
	SUD int default -1,
	SSNValid int,
	ReportID int,
	Step nvarchar(10) not NULL,
	constraint pk_tlsa_Person primary key clustered (PersonalID) 
	)
	;


if object_id ('ch_Exclude') is not NULL drop table ch_Exclude

	create table ch_Exclude(
	PersonalID nvarchar(32) not NULL,
	excludeDate date not NULL,
	Step nvarchar(10) not NULL,
	constraint pk_ch_Exclude primary key clustered (PersonalID, excludeDate) 
	)
	;

if object_id ('ch_Include') is not NULL drop table ch_Include
	
	create table ch_Include(
	PersonalID nvarchar(32) not NULL,
	ESSHStreetDate date not NULL,
	Step nvarchar(10) not NULL,
	constraint pk_ch_Include primary key clustered (PersonalID, ESSHStreetDate)
	)
	;
	
if object_id ('ch_Episodes') is not NULL drop table ch_Episodes
	create table ch_Episodes(
	PersonalID nvarchar(32),
	episodeStart date,
	episodeEnd date,
	episodeDays int null,
	Step nvarchar(10) not NULL,
	constraint pk_ch_Episodes primary key clustered (PersonalID, episodeStart)
	)
	;

if object_id ('tlsa_Household') is not NULL drop table tlsa_Household

create table tlsa_Household(
	HoHID nvarchar(32) not NULL,
	HHType int not null,
	FirstEntry date,
	LastInactive date,
	Stat int,
	StatEnrollmentID nvarchar(32),
	ReturnTime int,
	HHChronic int,
	HHVet int,
	HHDisability int,
	HHFleeingDV int,
	HoHRaceEthnicity int,
	HHAdult int,
	HHChild int,
	HHNoDOB int,
	HHAdultAge int,
	HHParent int,
	ESTStatus int,
	ESTGeography int,
	ESTLivingSit int,
	ESTDestination int,
	ESTChronic int,
	ESTVet int,
	ESTDisability int,
	ESTFleeingDV int,
	ESTAC3Plus int,
	ESTAdultAge int,
	ESTParent int,
	RRHStatus int,
	RRHMoveIn int,
	RRHGeography int,
	RRHLivingSit int,
	RRHDestination int,
	RRHPreMoveInDays int,
	RRHChronic int,
	RRHVet int,
	RRHDisability int,
	RRHFleeingDV int,
	RRHAC3Plus int,
	RRHAdultAge int,
	RRHParent int,
	PSHStatus int,
	PSHMoveIn int,
	PSHGeography int,
	PSHLivingSit int,
	PSHDestination int,
	PSHHousedDays int,
	PSHChronic int,
	PSHVet int,
	PSHDisability int,
	PSHFleeingDV int,
	PSHAC3Plus int,
	PSHAdultAge int,
	PSHParent int,
	ESDays int,
	THDays int,
	ESTDays int,
	RRHPSHPreMoveInDays int,
	RRHHousedDays int,
	SystemDaysNotPSHHoused int,
	SystemHomelessDays int,
	Other3917Days int,
	TotalHomelessDays int,
	SystemPath int,
	ESTAHAR int,
	RRHAHAR int,
	PSHAHAR int,
	RRHSOStatus int,
	RRHSOMoveIn int,
	ReportID int,
	Step nvarchar(10) not NULL,
	constraint pk_tlsa_Household primary key clustered (HoHID, HHType)
	)
	;

	if object_id ('sys_TimePadded') is not null drop table sys_TimePadded
	
	create table sys_TimePadded (
	HoHID nvarchar(32) not null
	, HHType int not null
	, Cohort int not null
	, StartDate date
	, EndDate date
	, Step nvarchar(10) not NULL
	)
	;

	if object_id ('sys_Time') is not null drop table sys_Time
	
	create table sys_Time (
		HoHID nvarchar(32)
		, HHType int
		, sysDate date
		, sysStatus int
		, Step nvarchar(10) not NULL
		, constraint pk_sys_Time primary key clustered (HoHID, HHType, sysDate)
		)
		;

	if object_id ('tlsa_Exit') is not NULL drop table tlsa_Exit
 
	create table tlsa_Exit(
		HoHID nvarchar(32) not null,
		HHType int not null,
		QualifyingExitHHID nvarchar(32),
		LastInactive date,
		Cohort int not NULL,
		Stat int,
		ExitFrom int,
		ExitTo int,
		ReturnTime int,
		HHVet int,
		HHChronic int,
		HHDisability int,
		HHFleeingDV int,
		HoHRaceEthnicity int,
		HHAdultAge int,
		HHParent int,
		AC3Plus int,
		SystemPath int,
		ReportID int not NULL,
		Step nvarchar(10) not NULL,
		constraint pk_tlsa_Exit primary key (Cohort, HoHID, HHType)
		)
		;
		
	if object_id ('ch_Exclude_exit') is not NULL drop table ch_Exclude_exit

		create table ch_Exclude_exit (
		PersonalID nvarchar(32) not NULL,
		excludeDate date not NULL,
		Step nvarchar(10) not NULL,
		constraint pk_ch_Exclude_exit primary key clustered (PersonalID, excludeDate) 
		)
		;

	if object_id ('ch_Include_exit') is not NULL drop table ch_Include_exit
	
		create table ch_Include_exit (
		PersonalID nvarchar(32) not NULL,
		ESSHStreetDate date not NULL,
		Step nvarchar(10) not NULL,
		constraint pk_ch_Include_exit primary key clustered (PersonalID, ESSHStreetDate)
		)
		;
	
	if object_id ('ch_Episodes_exit') is not NULL drop table ch_Episodes_exit
		create table ch_Episodes_exit (
		PersonalID nvarchar(32),
		episodeStart date,
		episodeEnd date,
		episodeDays int null,
		Step nvarchar(10) not NULL,
		constraint pk_ch_Episodes_exit primary key clustered (PersonalID, episodeStart)
		)
		;

	if object_id ('sys_TimePadded_exit') is not null drop table sys_TimePadded_exit
	
		create table sys_TimePadded_exit (
		HoHID nvarchar(32) not null
		, HHType int not null
		, Cohort int not null
		, StartDate date
		, EndDate date
		, Step nvarchar(10) not NULL
		)
		;

	if object_id ('tlsa_ExitHoHAdult') is not NULL drop table tlsa_ExitHoHAdult;
 
	create table tlsa_ExitHoHAdult(
		PersonalID nvarchar(32) not null,
		QualifyingExitHHID nvarchar(32),
		Cohort int not NULL,
		DisabilityStatus int,
		CHStart date,
		LastActive date,
		CHTime int,
		CHTimeStatus int,
		Step nvarchar(10) not NULL,
		constraint pk_tlsa_ExitHoHAdult primary key (PersonalID, QualifyingExitHHID, Cohort)
		)
		;

	if object_id ('tlsa_AveragePops') is not null drop table tlsa_AveragePops;

	create table tlsa_AveragePops (
		PopID int
		, Cohort int
		, HoHID nvarchar(32)
		, HHType int
		, Step nvarchar(10) not null)
		;

		--create index tlsa_AveragePops_PopID_Cohort on tlsa_AveragePops (PopID, Cohort) include (HoHID, HHType)

	if object_id ('tlsa_CountPops') is not null drop table tlsa_CountPops;

	create table tlsa_CountPops (
		PopID int
		, PersonalID nvarchar(32)
		, HouseholdID nvarchar(32)
		, Step nvarchar(10) not null)
		;

	if object_id ('ref_Calendar') is not null drop table ref_Calendar
	create table ref_Calendar (
		theDate date not null 
		, yyyy smallint
		, mm tinyint 
		, dd tinyint
		, month_name nvarchar(10)
		, day_name nvarchar(10) 
		, fy smallint
		, constraint pk_ref_Calendar primary key clustered (theDate) 
	)
	;

	--Populate ref_Calendar
	declare @start date = '2012-10-01'
	declare @end date = '2025-09-30'
	declare @i int = 0
	declare @total_days int = DATEDIFF(d, @start, @end) 

	while @i <= @total_days
	begin
			insert into ref_Calendar (theDate) 
			select cast(dateadd(d, @i, @start) as date) 
			set @i = @i + 1
	end

	update ref_Calendar
	set	month_name = datename(month, theDate),
		day_name = datename(weekday, theDate),
		yyyy = datepart(yyyy, theDate),
		mm = datepart(mm, theDate),
		dd = datepart(dd, theDate),
		fy = case when datepart(mm, theDate) between 10 and 12 then datepart(yyyy, theDate) + 1 
			else datepart(yyyy, theDate) end

;

	if object_id ('ref_RowPopulations') is not null drop table ref_RowPopulations
	create table ref_RowPopulations (
		RowMin int
		, RowMax int
		, ByPath int 
		, ByProject int
		, PopID int
		, Pop1 int
		, Pop2 int
		)
;

	if object_id ('ref_PopHHTypes') is not null drop table ref_PopHHTypes
	create table ref_PopHHTypes (
		PopID int not null
		, HHType int not null
		, constraint pk_ref_PopHHTypes primary key clustered (PopID, HHType)
)
;



