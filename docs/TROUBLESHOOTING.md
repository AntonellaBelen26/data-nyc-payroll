# Troubleshooting

## 1. ADLS `EndpointUnsupportedAccountFeatures` / conflict error
- Cause: the storage account is not ADLS Gen2 (hierarchical namespace disabled).
- Check: Storage account > Configuration (or Overview) > Hierarchical namespace = Enabled.
- Fix: if it was created incorrectly, recreate the storage account with Hierarchical namespace enabled (Advanced tab), re-upload the files, and update the linked service. (An in-place upgrade exists for some accounts but has restrictions; recreating is the safe path for this project.)
- Linked service type must be `AzureBlobFS` with the `dfs.core.windows.net` endpoint.

## 2. `MissingRequiredPropertyException` (Azure SQL linked service)
- Seen when creating a Mapping Data Flow with the Azure SQL linked service.
- Check: server, database, authentication type and credentials are all filled in and the connection test passes.
- Project workaround: in the linked service, set **Version = Legacy** (Advanced), save, publish and reopen the data flow. Document this if used.

## 3. `FiscalYear` column not found in the staging dataset
- Import the schema of `DS_ADLS_PAYROLL_SUMMARY_STAGING` (or define it manually) with exactly `FiscalYear`, `AgencyName`, `TotalPaid`.
- Ensure the sink mapping matches those names and the dataset's header setting matches the files actually written.

## 4. `AgencyID` missing from 2021 payroll
- The 2021 source and table use `AgencyCode`. In the Select transformation for 2021, map `AgencyCode` -> `AgencyID` before the Union. Never reference `AgencyID` directly from the 2021 source.

## 5. Union incompatible schema
- Add a Select after each source; align column names, order and data types (identical on both sides) before the Union. Use Union by name only when names match exactly.

## 6. Null `TotalPaid`
- Use `coalesce(RegularGrossPaid,0.0) + coalesce(TotalOTPaid,0.0) + coalesce(TotalOtherPay,0.0)`.

## 7. Synapse external table returns no rows or parsing errors
- Verify `dirstaging` path and the container in `eds_nycpayroll_adls` (`sql/03`).
- Verify the pipeline actually wrote files (`sql/04` section G1; ADLS browser).
- Verify delimiter is `,` and header handling: ADF sink without header <-> `FIRST_ROW = 1`; with header -> `FIRST_ROW = 2`.
- Verify the file format (`ff_csv_comma`), UTF-8 encoding and column count/order (`FiscalYear, AgencyName, TotalPaid`).
- Verify the managed identity has **Storage Blob Data Reader** (or a valid SAS in the credential).
- Run the `udacity` queries in the serverless endpoint, not a dedicated pool.

## 8. Source-data observations
- `nycpayroll_2020.csv` contains 1 row with FiscalYear 1998; `nycpayroll_2021.csv` contains 1 row with FiscalYear 1999. They are loaded as-is; the summary filter `FiscalYear >= parameter` excludes them. Report them as data-quality exceptions.
- `AgencyStartDate` is `M/d/yyyy`; convert explicitly in data flows.
