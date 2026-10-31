/*==============================================================================
  04_validation_queries.sql
  Data-quality and reconciliation checks. Read-only (SELECT only).
  Run each SECTION against the database named in its header.
    SECTION A-F : Azure SQL Database  db_nycpayroll
    SECTION G   : Synapse serverless  udacity

  Expected source row counts (data rows, excluding header) from the repo CSVs:
    AgencyMaster 153 | EmpMaster 1000 | TitleMaster 1446
    nycpayroll_2020 100 | nycpayroll_2021 101
  Known source observations (reported, not auto-corrected):
    - nycpayroll_2020.csv has 99 rows FiscalYear=2020 and 1 row FiscalYear=1998
    - nycpayroll_2021.csv has 100 rows FiscalYear=2021 and 1 row FiscalYear=1999
  Negative payments are REPORTED as exceptions, never rejected.
==============================================================================*/

/*==================== SECTION A (Azure SQL): row counts =====================*/
SELECT 'NYC_Payroll_AGENCY_MD'  AS TableName, COUNT(*) AS RowCnt, 153  AS ExpectedFromCsv FROM dbo.NYC_Payroll_AGENCY_MD
UNION ALL SELECT 'NYC_Payroll_EMP_MD',    COUNT(*), 1000 FROM dbo.NYC_Payroll_EMP_MD
UNION ALL SELECT 'NYC_Payroll_TITLE_MD',  COUNT(*), 1446 FROM dbo.NYC_Payroll_TITLE_MD
UNION ALL SELECT 'NYC_Payroll_Data_2020', COUNT(*), 100  FROM dbo.NYC_Payroll_Data_2020
UNION ALL SELECT 'NYC_Payroll_Data_2021', COUNT(*), 101  FROM dbo.NYC_Payroll_Data_2021
UNION ALL SELECT 'NYC_Payroll_Summary',   COUNT(*), NULL FROM dbo.NYC_Payroll_Summary;
-- Source-to-sink reconciliation: compare RowCnt with ExpectedFromCsv and with the
-- ADF data flow run output (rows written per sink) from the Monitor tab.
-- Duplicates caused by a rerun without truncate would show RowCnt = multiple of expected.

/*==================== SECTION B (Azure SQL): null checks ====================*/
SELECT 'EMP_MD null EmployeeID' AS Chk, COUNT(*) AS Cnt FROM dbo.NYC_Payroll_EMP_MD WHERE EmployeeID IS NULL OR LTRIM(RTRIM(EmployeeID)) = ''
UNION ALL SELECT 'Data_2020 null EmployeeID', COUNT(*) FROM dbo.NYC_Payroll_Data_2020 WHERE EmployeeID IS NULL OR LTRIM(RTRIM(EmployeeID)) = ''
UNION ALL SELECT 'Data_2021 null EmployeeID', COUNT(*) FROM dbo.NYC_Payroll_Data_2021 WHERE EmployeeID IS NULL OR LTRIM(RTRIM(EmployeeID)) = ''
UNION ALL SELECT 'AGENCY_MD null AgencyName', COUNT(*) FROM dbo.NYC_Payroll_AGENCY_MD WHERE AgencyName IS NULL OR LTRIM(RTRIM(AgencyName)) = ''
UNION ALL SELECT 'Data_2020 null AgencyName', COUNT(*) FROM dbo.NYC_Payroll_Data_2020 WHERE AgencyName IS NULL OR LTRIM(RTRIM(AgencyName)) = ''
UNION ALL SELECT 'Data_2021 null AgencyName', COUNT(*) FROM dbo.NYC_Payroll_Data_2021 WHERE AgencyName IS NULL OR LTRIM(RTRIM(AgencyName)) = ''
UNION ALL SELECT 'Summary null AgencyName',   COUNT(*) FROM dbo.NYC_Payroll_Summary    WHERE AgencyName IS NULL OR LTRIM(RTRIM(AgencyName)) = '';

/*============ SECTION C (Azure SQL): unsupported FiscalYear values ==========*/
-- Table 2020 should only hold 2020; table 2021 only 2021. Rows listed are exceptions.
SELECT 'Data_2020' AS Src, FiscalYear, COUNT(*) AS Cnt FROM dbo.NYC_Payroll_Data_2020 GROUP BY FiscalYear HAVING FiscalYear IS NULL OR FiscalYear <> 2020
UNION ALL
SELECT 'Data_2021', FiscalYear, COUNT(*) FROM dbo.NYC_Payroll_Data_2021 GROUP BY FiscalYear HAVING FiscalYear IS NULL OR FiscalYear <> 2021;
-- Summary should only contain 2020/2021 (the filter keeps FiscalYear >= parameter).
SELECT FiscalYear, COUNT(*) AS Cnt FROM dbo.NYC_Payroll_Summary
WHERE FiscalYear IS NULL OR FiscalYear NOT IN (2020, 2021) GROUP BY FiscalYear;

/*================ SECTION D (Azure SQL): duplicates and masters =============*/
SELECT EmployeeID, COUNT(*) AS Cnt FROM dbo.NYC_Payroll_EMP_MD GROUP BY EmployeeID HAVING COUNT(*) > 1;
SELECT AgencyID,   COUNT(*) AS Cnt FROM dbo.NYC_Payroll_AGENCY_MD GROUP BY AgencyID HAVING COUNT(*) > 1;
SELECT TitleCode,  COUNT(*) AS Cnt FROM dbo.NYC_Payroll_TITLE_MD GROUP BY TitleCode HAVING COUNT(*) > 1;
-- Fully duplicated payroll rows (rerun without truncate, or genuine source duplicates)
SELECT FiscalYear, PayrollNumber, AgencyID, EmployeeID, TitleCode, BaseSalary, COUNT(*) AS Cnt
FROM dbo.NYC_Payroll_Data_2020
GROUP BY FiscalYear, PayrollNumber, AgencyID, EmployeeID, TitleCode, BaseSalary HAVING COUNT(*) > 1;
SELECT FiscalYear, PayrollNumber, AgencyCode, EmployeeID, TitleCode, BaseSalary, COUNT(*) AS Cnt
FROM dbo.NYC_Payroll_Data_2021
GROUP BY FiscalYear, PayrollNumber, AgencyCode, EmployeeID, TitleCode, BaseSalary HAVING COUNT(*) > 1;

-- Invalid / unmapped agency identifiers (reported as exceptions)
SELECT '2020' AS Src, p.AgencyID AS AgencyKey, COUNT(*) AS Cnt
FROM dbo.NYC_Payroll_Data_2020 p LEFT JOIN dbo.NYC_Payroll_AGENCY_MD a ON a.AgencyID = p.AgencyID
WHERE p.AgencyID IS NULL OR a.AgencyID IS NULL GROUP BY p.AgencyID
UNION ALL
SELECT '2021', p.AgencyCode, COUNT(*)
FROM dbo.NYC_Payroll_Data_2021 p LEFT JOIN dbo.NYC_Payroll_AGENCY_MD a ON a.AgencyID = p.AgencyCode
WHERE p.AgencyCode IS NULL OR a.AgencyID IS NULL GROUP BY p.AgencyCode;

-- Payroll employees not present in EmpMaster / titles not in TitleMaster
SELECT 'EmployeeID not in EMP_MD' AS Chk, COUNT(*) AS Cnt FROM
 (SELECT EmployeeID FROM dbo.NYC_Payroll_Data_2020 UNION ALL SELECT EmployeeID FROM dbo.NYC_Payroll_Data_2021) p
 WHERE NOT EXISTS (SELECT 1 FROM dbo.NYC_Payroll_EMP_MD e WHERE e.EmployeeID = p.EmployeeID)
UNION ALL
SELECT 'TitleCode not in TITLE_MD', COUNT(*) FROM
 (SELECT TitleCode FROM dbo.NYC_Payroll_Data_2020 UNION ALL SELECT TitleCode FROM dbo.NYC_Payroll_Data_2021) p
 WHERE NOT EXISTS (SELECT 1 FROM dbo.NYC_Payroll_TITLE_MD t WHERE t.TitleCode = p.TitleCode);

/*============ SECTION E (Azure SQL): negative payments (exceptions) =========*/
SELECT 2020 AS Src, FiscalYear, PayrollNumber, EmployeeID, AgencyName, RegularGrossPaid, TotalOTPaid, TotalOtherPay
FROM dbo.NYC_Payroll_Data_2020 WHERE RegularGrossPaid < 0 OR TotalOTPaid < 0 OR TotalOtherPay < 0
UNION ALL
SELECT 2021, FiscalYear, PayrollNumber, EmployeeID, AgencyName, RegularGrossPaid, TotalOTPaid, TotalOtherPay
FROM dbo.NYC_Payroll_Data_2021 WHERE RegularGrossPaid < 0 OR TotalOTPaid < 0 OR TotalOtherPay < 0;

/*====== SECTION F (Azure SQL): summary reconciliation & TotalPaid check =====*/
-- Recompute expected summary from detail tables for the fiscal year(s) kept by the
-- data flow filter (FiscalYear >= @param). Set @fy to the value used in the run.
DECLARE @fy int = 2020;   -- must equal global_param_fiscalyear used in the pipeline run

WITH detail AS (
    SELECT FiscalYear, AgencyName,
           COALESCE(RegularGrossPaid,0.0) + COALESCE(TotalOTPaid,0.0) + COALESCE(TotalOtherPay,0.0) AS TotalPaid
    FROM dbo.NYC_Payroll_Data_2020
    UNION ALL
    SELECT FiscalYear, AgencyName,
           COALESCE(RegularGrossPaid,0.0) + COALESCE(TotalOTPaid,0.0) + COALESCE(TotalOtherPay,0.0)
    FROM dbo.NYC_Payroll_Data_2021
),
expected AS (
    SELECT FiscalYear, AgencyName, SUM(TotalPaid) AS ExpectedTotalPaid
    FROM detail WHERE FiscalYear >= @fy GROUP BY FiscalYear, AgencyName
)
SELECT COALESCE(e.FiscalYear, s.FiscalYear) AS FiscalYear,
       COALESCE(e.AgencyName, s.AgencyName) AS AgencyName,
       e.ExpectedTotalPaid, s.TotalPaid AS SummaryTotalPaid,
       ABS(COALESCE(e.ExpectedTotalPaid,0) - COALESCE(s.TotalPaid,0)) AS AbsDiff
FROM expected e
FULL OUTER JOIN dbo.NYC_Payroll_Summary s
  ON s.FiscalYear = e.FiscalYear AND s.AgencyName = e.AgencyName
WHERE e.FiscalYear IS NULL OR s.FiscalYear IS NULL
   OR ABS(e.ExpectedTotalPaid - s.TotalPaid) > 0.01;   -- zero rows returned = reconciled

-- Grand totals per fiscal year: detail vs summary
SELECT d.FiscalYear, d.DetailTotal, s.SummaryTotal
FROM (SELECT FiscalYear, SUM(COALESCE(RegularGrossPaid,0.0)+COALESCE(TotalOTPaid,0.0)+COALESCE(TotalOtherPay,0.0)) AS DetailTotal
      FROM (SELECT FiscalYear, RegularGrossPaid, TotalOTPaid, TotalOtherPay FROM dbo.NYC_Payroll_Data_2020
            UNION ALL SELECT FiscalYear, RegularGrossPaid, TotalOTPaid, TotalOtherPay FROM dbo.NYC_Payroll_Data_2021) x
      GROUP BY FiscalYear) d
LEFT JOIN (SELECT FiscalYear, SUM(TotalPaid) AS SummaryTotal FROM dbo.NYC_Payroll_Summary GROUP BY FiscalYear) s
  ON s.FiscalYear = d.FiscalYear
ORDER BY d.FiscalYear;

-- Summary content
SELECT FiscalYear, COUNT(*) AS Agencies, SUM(TotalPaid) AS TotalPaid FROM dbo.NYC_Payroll_Summary GROUP BY FiscalYear;
SELECT TOP 20 * FROM dbo.NYC_Payroll_Summary ORDER BY TotalPaid DESC;

/*============ SECTION G (Synapse serverless, database udacity) ==============
  Run these in Synapse Studio connected to the serverless endpoint, database udacity.
  Replace <STORAGE_ACCOUNT_NAME>/<FILE_SYSTEM_NAME> only if you query the URL directly.

-- G1. Staging files exist (one row per file); zero rows = pipeline did not write output
SELECT r.filepath() AS FilePath, COUNT(*) AS RowCnt
FROM OPENROWSET(
        BULK 'dirstaging/*',
        DATA_SOURCE = 'eds_nycpayroll_adls',
        FORMAT = 'CSV', PARSER_VERSION = '2.0', FIRST_ROW = 1
     ) WITH (c1 varchar(200)) AS r
GROUP BY r.filepath();

-- G2. External table returns data
SELECT TOP 20 * FROM dbo.NYC_Payroll_Summary;
SELECT FiscalYear, COUNT(*) AS Agencies, SUM(TotalPaid) AS TotalPaid
FROM dbo.NYC_Payroll_Summary GROUP BY FiscalYear ORDER BY FiscalYear;

-- G3. Parsing sanity: should be 0 (a header row read as data would show NULL/err on cast)
SELECT COUNT(*) AS NullFiscalYear FROM dbo.NYC_Payroll_Summary WHERE FiscalYear IS NULL;

-- G4. Compare with Azure SQL: the per-year Agencies and TotalPaid values from G2 must
--     equal the Azure SQL dbo.NYC_Payroll_Summary results in SECTION F.
==============================================================================*/
