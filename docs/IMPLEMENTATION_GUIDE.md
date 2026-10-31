# Implementation Guide

Status legend: **[Repo]** done in this repository, **[Manual]** must be done in Azure Portal / ADF Studio, **[ADF-generated]** produced by ADF on Save/Publish.

## Step 1. Storage (ADLS Gen2) [Manual]
1. Create a storage account with **Hierarchical namespace enabled** (see TROUBLESHOOTING #1).
2. Create a file system (container) and folders `dirpayrollfiles`, `dirhistoryfiles`, `dirstaging`.
3. Upload from `Data/`:
   - `dirpayrollfiles/`: `EmpMaster.csv`, `AgencyMaster.csv`, `TitleMaster.csv`, `nycpayroll_2021.csv`
   - `dirhistoryfiles/`: `nycpayroll_2020.csv`

## Step 2. Azure SQL Database [Repo script + Manual execution]
1. Create database `db_nycpayroll`; allow your client IP and Azure services in the firewall.
2. Run `sql/01_create_azure_sql_tables.sql` (idempotent).
3. Verify 6 tables exist.

## Step 3. Synapse serverless SQL [Repo scripts + Manual execution]
1. Sign in to Synapse Studio with the Entra user that has a Storage Blob Data role on the storage account (pass-through, no secret).
2. Run `sql/02_create_synapse_database.sql` on `master`, then switch the database to `udacity`.
3. Replace `<STORAGE_ACCOUNT_NAME>` and `<FILE_SYSTEM_NAME>` in `sql/03_create_synapse_external_objects.sql`, run it on `udacity`.
   Queries return data only after the first pipeline run.

## Step 4. ADF artifacts [Repo authored; Manual in ADF Studio]
The JSON for linked services, datasets, data flows and the pipeline is in the repo root folders (authored offline, not yet opened in ADF Studio).
1. Create the Data Factory and connect it to the GitHub repository (collaboration branch, root folder `/`).
2. Place/merge these folders into the collaboration branch.
3. Edit `LS_ADLS_NYC_PAYROLL`: set the storage account name; authenticate with account key (entered in the UI, never in Git) or grant the ADF managed identity Storage Blob Data Reader.
4. Edit `LS_AZURE_SQL_NYC_PAYROLL`: set SQL login and password in the UI; set Version = Legacy if Mapping Data Flow fails with MissingRequiredPropertyException. Test connection.
5. Manage > Global parameters > New: `global_param_fiscalyear`, Int, 2020 (see `docs/global_param_fiscalyear.reference.json`).
6. Open every data flow, turn on Data flow debug, check Data preview and fix any validation error. Confirm container name `nycpayroll` in the ADLS datasets.
7. Save all and Publish.
Credentials are entered only in ADF Studio / Key Vault, never in Git.

## Step 5. Run and validate [Manual]
1. Run the pipeline (global parameter `global_param_fiscalyear` = 2020 or 2021).
2. Run `sql/04_validation_queries.sql` (sections A-F on Azure SQL, section G on Synapse).
3. Capture screenshots per `docs/SCREENSHOT_CHECKLIST.md`.

## Design decisions
- Ingestion sinks: truncate-before-load, so reruns do not create duplicates. Running a single payroll flow alone replaces only its own table.
- Summary SQL sink: truncate; staging sink: clear the folder. Each run reflects the chosen fiscal-year filter only.
- Staging files: comma-delimited, no header, columns `FiscalYear, AgencyName, TotalPaid`; matches `ff_csv_comma` (`FIRST_ROW = 1`).
- No secrets in the repo; Synapse uses Entra user pass-through.
