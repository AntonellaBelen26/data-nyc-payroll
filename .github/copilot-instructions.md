# Copilot instructions for this repository

NYC Payroll Data Engineering project: ADLS Gen2, Azure SQL Database, Azure Data Factory (Mapping Data Flows), Synapse serverless SQL, GitHub. Do not change these technologies.

- Preserve ADF's native repository layout and JSON format (`linkedService/`, `dataset/`, `dataflow/`, `pipeline/`). Do not overwrite ADF-generated JSON unless a change is needed.
- Never commit passwords, keys, SAS tokens, connection strings with secrets, subscription IDs or tenant IDs. Use placeholders like `<STORAGE_ACCOUNT_NAME>`.
- Names: `LS_ADLS_NYC_PAYROLL`, `LS_AZURE_SQL_NYC_PAYROLL`, `DS_ADLS_*`, `DS_SQL_*`, `DF_*`, `PL_NYC_PAYROLL_LOAD_AND_SUMMARY`.
- 2020 payroll uses `AgencyID`; 2021 uses `AgencyCode`. Map `AgencyCode` -> `AgencyID` before the Union.
- `TotalPaid` must use `coalesce` on all three pay components.
- Global parameter: `@pipeline().globalParameters.global_param_fiscalyear` -> `dataflow_param_fiscalyear`.
- Synapse: serverless SQL only (external file format, external data source, external table over `dirstaging`); no dedicated pool.
- Report negative payments as data-quality exceptions; do not reject them.
- Do not claim anything is deployed or executed without evidence in the repo. Do not fabricate screenshots.
- After changes, run `powershell -File scripts\validate-adf.ps1`.
