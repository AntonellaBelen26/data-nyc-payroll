/*==============================================================================
  03_create_synapse_external_objects.sql
  Target : Synapse SERVERLESS SQL, database 'udacity'
  Purpose: External file format, external data source and external table over
           the ADLS Gen2 'dirstaging' folder written by DF_PAYROLL_SUMMARY.
  Prereq : 02_create_synapse_database.sql executed. Run this script signed in
           with an Entra user that has a Storage Blob Data role on the account.
  Rerun  : Safe (existence checks; objects are not dropped).
  Repo review: no pre-existing external data source, credential or file format
           definitions were found in the repository, so none were reused.

  PLACEHOLDERS TO REPLACE
  -----------------------
  <STORAGE_ACCOUNT_NAME>  ADLS Gen2 storage account name (hierarchical namespace ON)
  <FILE_SYSTEM_NAME>      Container (file system) that holds dirstaging/
  Resulting location: https://<STORAGE_ACCOUNT_NAME>.dfs.core.windows.net/<FILE_SYSTEM_NAME>
  (If dirstaging is not at the container root, adjust LOCATION in the external
   table, not the data source.)

  FILE-FORMAT CONTRACT with the ADF staging sink (DS_ADLS_PAYROLL_SUMMARY_STAGING)
  - comma delimited, UTF-8, NO header row written by ADF (FIRST_ROW = 1 below).
    If you choose to write a header in ADF, change FIRST_ROW to 2.
  - column order: FiscalYear, AgencyName, TotalPaid
  Serverless SQL ignores files/folders starting with '_' or '.', so ADF
  bookkeeping files do not break reads.
  Note: CETAS is not used here because the data is produced by ADF; the table is
  a plain external table over existing files, which is serverless-compatible.
==============================================================================*/

-- Run while connected to: udacity

IF NOT EXISTS (SELECT 1 FROM sys.external_file_formats WHERE name = N'ff_csv_comma')
    CREATE EXTERNAL FILE FORMAT ff_csv_comma
    WITH (
        FORMAT_TYPE = DELIMITEDTEXT,
        FORMAT_OPTIONS (
            FIELD_TERMINATOR = ',',
            STRING_DELIMITER = '"',
            FIRST_ROW        = 1,        -- ADF sink writes no header
            USE_TYPE_DEFAULT = FALSE,
            ENCODING         = 'UTF8',
            PARSER_VERSION   = '2.0'
        )
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = N'eds_nycpayroll_adls')
    CREATE EXTERNAL DATA SOURCE eds_nycpayroll_adls
    WITH (
        -- REPLACE both placeholders. No CREDENTIAL: Entra user pass-through is used.
        -- (To use a credential instead, see the alternatives in 02_create_synapse_database.sql.)
        LOCATION = 'https://<STORAGE_ACCOUNT_NAME>.dfs.core.windows.net/<FILE_SYSTEM_NAME>'
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.external_tables WHERE name = N'NYC_Payroll_Summary')
CREATE EXTERNAL TABLE dbo.NYC_Payroll_Summary
(
    FiscalYear  int,
    AgencyName  varchar(50),
    TotalPaid   float
)
WITH (
    LOCATION    = 'dirstaging/',
    DATA_SOURCE = eds_nycpayroll_adls,
    FILE_FORMAT = ff_csv_comma
);
GO

-- Verification
SELECT name, location FROM sys.external_data_sources;
SELECT name, format_type FROM sys.external_file_formats;
SELECT name FROM sys.external_tables;
SELECT TOP 10 * FROM dbo.NYC_Payroll_Summary;   -- needs files in dirstaging
