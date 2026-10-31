/*==============================================================================
  01_create_azure_sql_tables.sql
  Target : Azure SQL Database  db_nycpayroll   (NOT Synapse)
  Purpose: Creates the six tables required by the NYC Payroll project.
  Rerun  : Safe. Each table is created only if it does not already exist.
           Existing tables are never dropped or altered by this script.
  Notes  : - Column names/types follow the project specification exactly.
           - NYC_Payroll_Data_2020 uses AgencyID; NYC_Payroll_Data_2021 uses
             AgencyCode (intentional source difference). DF_PAYROLL_SUMMARY must
             map AgencyCode -> AgencyID before the Union.
           - No primary keys: the source files contain no guaranteed unique key
             (an employee can appear in several payroll rows). Loads are made
             rerunnable by truncating the sink table before insert (data flow
             sink setting), not by constraints.
           - No secrets or environment-specific values are used in this file.
==============================================================================*/

-- Run while connected to db_nycpayroll.

IF OBJECT_ID(N'dbo.NYC_Payroll_EMP_MD', N'U') IS NULL
CREATE TABLE dbo.NYC_Payroll_EMP_MD
(
    EmployeeID  varchar(10),
    LastName    varchar(20),
    FirstName   varchar(20)
);
GO

IF OBJECT_ID(N'dbo.NYC_Payroll_TITLE_MD', N'U') IS NULL
CREATE TABLE dbo.NYC_Payroll_TITLE_MD
(
    TitleCode        varchar(10),
    TitleDescription varchar(100)
);
GO

IF OBJECT_ID(N'dbo.NYC_Payroll_AGENCY_MD', N'U') IS NULL
CREATE TABLE dbo.NYC_Payroll_AGENCY_MD
(
    AgencyID    varchar(10),
    AgencyName  varchar(50)
);
GO

IF OBJECT_ID(N'dbo.NYC_Payroll_Data_2020', N'U') IS NULL
CREATE TABLE dbo.NYC_Payroll_Data_2020
(
    FiscalYear            int,
    PayrollNumber         int,
    AgencyID              varchar(10),
    AgencyName            varchar(50),
    EmployeeID            varchar(10),
    LastName              varchar(20),
    FirstName             varchar(20),
    AgencyStartDate       date,
    WorkLocationBorough   varchar(50),
    TitleCode             varchar(10),
    TitleDescription      varchar(100),
    LeaveStatusasofJune30 varchar(50),
    BaseSalary            float,
    PayBasis              varchar(50),
    RegularHours          float,
    RegularGrossPaid      float,
    OTHours               float,
    TotalOTPaid           float,
    TotalOtherPay         float
);
GO

IF OBJECT_ID(N'dbo.NYC_Payroll_Data_2021', N'U') IS NULL
CREATE TABLE dbo.NYC_Payroll_Data_2021
(
    FiscalYear            int,
    PayrollNumber         int,
    AgencyCode            varchar(10),   -- 2021 uses AgencyCode (not AgencyID)
    AgencyName            varchar(50),
    EmployeeID            varchar(10),
    LastName              varchar(20),
    FirstName             varchar(20),
    AgencyStartDate       date,
    WorkLocationBorough   varchar(50),
    TitleCode             varchar(10),
    TitleDescription      varchar(100),
    LeaveStatusasofJune30 varchar(50),
    BaseSalary            float,
    PayBasis              varchar(50),
    RegularHours          float,
    RegularGrossPaid      float,
    OTHours               float,
    TotalOTPaid           float,
    TotalOtherPay         float
);
GO

IF OBJECT_ID(N'dbo.NYC_Payroll_Summary', N'U') IS NULL
CREATE TABLE dbo.NYC_Payroll_Summary
(
    FiscalYear  int,
    AgencyName  varchar(50),
    TotalPaid   float
);
GO

-- Verification: expect 6 rows
SELECT name FROM sys.tables
WHERE name IN (N'NYC_Payroll_EMP_MD', N'NYC_Payroll_TITLE_MD', N'NYC_Payroll_AGENCY_MD',
               N'NYC_Payroll_Data_2020', N'NYC_Payroll_Data_2021', N'NYC_Payroll_Summary')
ORDER BY name;
