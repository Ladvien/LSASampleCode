# LSA in Dbt

## TODO:
- Dbt'ize the following files:
    - 00 Totally Optional HMIS Table Indexes.sql
    - 01 Temp Reporting and Reference Tables.sql
    - 02 LSA Output Tables.sql
    - 03_01a LSA Parameters and Metadata.sql
    - 03_01b LSA Parameters and Metadata for HIC.sql
    - 03_02 to 03_06 HMIS Households and Enrollments.sql
    - 04_01 Get Project Records.sql
    - 04_02 to 04_08 Get Other PDDEs.sql
    - 05_01 to 05_11 LSAPerson Records and Demographics.sql
    - 05_12 to 05_15 LSAPerson Project Group and Population Household Types.sql
    - 06 LSAHousehold.sql
    - 07 LSAExit.sql
    - 08 LSACalculated Averages for LSAHousehold and LSAExit.sql
    - 09 LSACalculated AHAR Counts.sql
    - 10 LSACalculated Data Quality.sql
    - 11 LSAReport DQ and ReportDate.sql

- Define the columns for the CSV Export seeds (datatypes, tests, etc.)

## Done
- Load HMIS CSV Export seeds
- Define YAML for CSV Export seeds


### Using the starter project
1. Install PostgresSQL locally https://docs.getdbt.com/docs/core/connect-data-platform/postgres-setup
2. Setup `profiles.yml`
3. Connect to `postgres` server and run `CREATE DATABASE home;`
4. Run `dbt debug` in the terminal from the project root.
5. Run `dbt deps` to install the `external-tables` dependency.

### Load Data
This Dbt project depends on the HMIS CSV Exports being loaded via Dbt's [seeds](https://docs.getdbt.com/docs/build/seeds) command. This allows one to pull load data directly from the CSV Export folder.

To load your source data (CSV Export) into the datawarehouse do the following

1. Update the `seeds` directory in the `dbt_project.yml` file.  There should be a reference to a folder where the CSVs are.
2. At the root of your Dbt project run `dbt seed`.  You should see output similar to:
```sh
...
14:55:05  24 of 24 START seed file lsa.YouthEducationStatus .............................. [RUN]
14:55:05  24 of 24 OK loaded seed file lsa.YouthEducationStatus .......................... [INSERT 0 in 0.03s]
14:55:05  
14:55:05  Finished running 24 seeds in 0 hours 3 minutes and 8.93 seconds (188.93s).
14:55:05  
14:55:05  Completed successfully
14:55:05  
14:55:05  Done. PASS=24 WARN=0 ERROR=0 SKIP=0 TOTAL=24
```
If all the data load correctly you are ready to move on to the next step.

### Building the data models
