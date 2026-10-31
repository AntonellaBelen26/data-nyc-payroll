# Screenshot Checklist

Screenshots are stored under `screenshots/`. They were captured manually from the Azure Portal, ADF Studio, Synapse Studio and GitHub.

| # | Evidence | File name | Captured |
|---|---|---|---|
| 1 | ADLS Gen2 showing uploaded source files (`dirpayrollfiles`, `dirhistoryfiles`) | `01_adls_source_files.png` | [x] |
| 2 | SQL Database showing all 6 required tables | `02_sql_tables.png` | [x] |
| 3 | Synapse external table creation (script run / success) | `03_synapse_external_table_creation.png` | [x] |
| 4 | ADF linked services | `04_adf_linked_services.png` | [x] |
| 5 | ADF datasets | `05_adf_datasets.png` | [x] |
| 6 | Individual ADF data flows (5 ingestion) | `06_adf_dataflows_ingestion.png` | [x] |
| 7 | Summary aggregation data flow (Union, Filter, Derived Column, Aggregate, 2 sinks) | `07_adf_dataflow_summary.jpg` | [x] |
| 8 | Final orchestration pipeline | `08_adf_pipeline.png` | [x] |
| 9 | Successful pipeline run | `09_pipeline_run_succeeded.png` | [x] |
| 10 | Successful activity runs | `10_activity_runs_succeeded.png` | [x] |
| 11 | SQL summary query results | `11_sql_summary_results.jpg` | [x] |
| 12 | Files created in `dirstaging` | `12_adls_dirstaging_files.png` | [x] |
| 13 | Synapse external table query results | `13_synapse_external_table_results.png` | [x] |
| 14 | GitHub repository containing published ADF artifacts | `14_github_adf_artifacts.png` | [x] |

Rules: crop out or blur subscription IDs, tenant IDs, keys and connection strings; do not edit result data.
