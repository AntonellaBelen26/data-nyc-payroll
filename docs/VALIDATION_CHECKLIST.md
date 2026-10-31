# Validation Checklist

Mark an item only when evidence exists. `[ ]` = not yet verified.

## Repository (Phase 2)
- [x] `sql/01`-`sql/04` exist, no secrets, placeholders documented
- [x] ADF JSON artifacts authored (21 files)
- [x] `scripts/validate-adf.ps1` passes (JSON, references, dependencies, secrets)
- [ ] Artifacts opened in ADF Studio without validation errors

## Azure SQL (run `sql/01`, `sql/04` A-F)
- [ ] 6 tables exist
- [ ] Row counts: Agency 153, Emp 1000, Title 1446, 2020 = 100, 2021 = 101
- [ ] No null EmployeeID / AgencyName (or exceptions documented)
- [ ] FiscalYear exceptions reviewed (source has 1 row FY1998 in the 2020 file, 1 row FY1999 in the 2021 file)
- [ ] No duplicate master keys / payroll rows after rerun
- [ ] Negative payments listed as exceptions (not rejected)
- [ ] Unmapped AgencyID/AgencyCode reviewed
- [ ] Summary reconciles to detail (section F returns 0 rows)
- [ ] TotalPaid = RegularGrossPaid + TotalOTPaid + TotalOtherPay with nulls treated as 0

## ADF (Phase 3 / manual)
- [ ] Linked services: AzureBlobFS and AzureSqlDatabase, connection tests pass
- [ ] 12 datasets; staging dataset schema has FiscalYear, AgencyName, TotalPaid
- [ ] 5 ingestion data flows + `DF_PAYROLL_SUMMARY` debug-validate without errors
- [ ] Pipeline dependencies: stage1 (3 parallel) -> stage2 (2 parallel) -> stage3, all `Succeeded`
- [ ] `global_param_fiscalyear` passed to `dataflow_param_fiscalyear`
- [ ] Pipeline run and all activity runs Succeeded

## Staging and Synapse (`sql/04` G)
- [ ] Files present in `dirstaging`
- [ ] External table returns rows; no parse errors; no header row read as data
- [ ] Synapse totals equal Azure SQL summary totals

## Security
- [ ] Repository scan finds no keys, SAS tokens, connection strings, passwords, subscription/tenant IDs
- [ ] Data in `Data/` confirmed as public NYC Open Data before publishing
