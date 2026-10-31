#requires -Version 5.1
<#
  Validates the ADF artifacts in this repository (offline).
  Checks: JSON syntax, linked service types, dataset -> linked service refs,
  data flow -> dataset refs, pipeline -> data flow refs, activity dependencies,
  global parameter expression, ingestion truncate behavior, secret patterns.
  Usage:  powershell -File scripts\validate-adf.ps1
#>
$root = Split-Path -Parent $PSScriptRoot
$errors = New-Object System.Collections.Generic.List[string]
function Fail($m) { $script:errors.Add($m); Write-Host "FAIL: $m" -ForegroundColor Red }
function Ok($m)   { Write-Host "OK:   $m" -ForegroundColor Green }

$folders = 'linkedService','dataset','dataflow','pipeline'
$objs = @{}
foreach ($f in $folders) {
    $dir = Join-Path $root $f
    if (-not (Test-Path $dir)) { Fail "Missing folder $f"; continue }
    Get-ChildItem $dir -Filter *.json | ForEach-Object {
        try {
            $j = Get-Content $_.FullName -Raw | ConvertFrom-Json
            if ($j.name -ne $_.BaseName) { Fail "$f/$($_.Name): name '$($j.name)' differs from file name" }
            $objs["$f/$($j.name)"] = $j
        } catch { Fail "$f/$($_.Name): invalid JSON - $($_.Exception.Message)" }
    }
}
Ok "Parsed $($objs.Count) ADF JSON files"

$ls = $objs.Keys | Where-Object { $_ -like 'linkedService/*' }
if ($objs['linkedService/LS_ADLS_NYC_PAYROLL'].properties.type -ne 'AzureBlobFS') { Fail 'LS_ADLS_NYC_PAYROLL type must be AzureBlobFS' } else { Ok 'ADLS linked service type AzureBlobFS' }
if ($objs['linkedService/LS_AZURE_SQL_NYC_PAYROLL'].properties.type -ne 'AzureSqlDatabase') { Fail 'LS_AZURE_SQL_NYC_PAYROLL type must be AzureSqlDatabase' } else { Ok 'SQL linked service type AzureSqlDatabase' }

$expectedDs = 'DS_ADLS_EMP_MASTER','DS_ADLS_AGENCY_MASTER','DS_ADLS_TITLE_MASTER','DS_ADLS_PAYROLL_2020','DS_ADLS_PAYROLL_2021','DS_ADLS_PAYROLL_SUMMARY_STAGING','DS_SQL_EMP_MASTER','DS_SQL_AGENCY_MASTER','DS_SQL_TITLE_MASTER','DS_SQL_PAYROLL_2020','DS_SQL_PAYROLL_2021','DS_SQL_PAYROLL_SUMMARY'
foreach ($d in $expectedDs) {
    $o = $objs["dataset/$d"]
    if (-not $o) { Fail "Missing dataset $d"; continue }
    if (-not $objs["linkedService/$($o.properties.linkedServiceName.referenceName)"]) { Fail "$d references unknown linked service" }
    $want = if ($d -like 'DS_ADLS_*') { 'DelimitedText' } else { 'AzureSqlTable' }
    if ($o.properties.type -ne $want) { Fail "$d type must be $want" }
    if ($d -like 'DS_ADLS_*' -and $o.properties.typeProperties.location.type -ne 'AzureBlobFSLocation') { Fail "$d must use AzureBlobFSLocation" }
}
Ok 'Datasets checked'
$stg = $objs['dataset/DS_ADLS_PAYROLL_SUMMARY_STAGING'].properties.schema.name -join ','
if ($stg -ne 'FiscalYear,AgencyName,TotalPaid') { Fail "Staging schema is '$stg'" } else { Ok 'Staging schema FiscalYear,AgencyName,TotalPaid' }

$expectedDf = 'DF_LOAD_EMP_MASTER','DF_LOAD_AGENCY_MASTER','DF_LOAD_TITLE_MASTER','DF_LOAD_PAYROLL_2020','DF_LOAD_PAYROLL_2021','DF_PAYROLL_SUMMARY'
$usedDs = New-Object System.Collections.Generic.HashSet[string]
foreach ($d in $expectedDf) {
    $o = $objs["dataflow/$d"]
    if (-not $o) { Fail "Missing data flow $d"; continue }
    if ($o.properties.type -ne 'MappingDataFlow') { Fail "$d not MappingDataFlow" }
    $script = $o.properties.typeProperties.scriptLines -join "`n"
    foreach ($s in @($o.properties.typeProperties.sources) + @($o.properties.typeProperties.sinks)) {
        $n = $s.dataset.referenceName; [void]$usedDs.Add($n)
        if (-not $objs["dataset/$n"]) { Fail "$d references unknown dataset $n" }
        if ($script -notmatch [regex]::Escape("~> $($s.name)")) { Fail "$d script lacks stream $($s.name)" }
    }
    if ($d -like 'DF_LOAD_*' -and $script -notmatch 'truncate:true') { Fail "$d sink is not rerunnable (truncate)" }
}
Ok 'Data flows checked'
foreach ($d in $expectedDs) { if (-not $usedDs.Contains($d)) { Fail "Orphan dataset $d (not used by any data flow)" } }

$sum = ($objs['dataflow/DF_PAYROLL_SUMMARY'].properties.typeProperties.scriptLines -join "`n")
foreach ($t in 'union\(','filter\(','derive\(','aggregate\(','AgencyID = AgencyCode','\$dataflow_param_fiscalyear','coalesce\(RegularGrossPaid, 0\.0\)','parameters\{') {
    if ($sum -notmatch $t) { Fail "DF_PAYROLL_SUMMARY missing pattern $t" }
}
if (([regex]::Matches($sum, '\) ~> sink')).Count -ne 2) { Fail 'DF_PAYROLL_SUMMARY must have 2 sinks' } else { Ok 'Summary flow has Union, Filter, Derived Column, Aggregate, 2 sinks' }
if ($sum -match 'srcPayroll2021 select\([^~]*\bAgencyID\b(?! = AgencyCode)') { Write-Host 'NOTE: verify 2021 select only maps AgencyID from AgencyCode' }

$pl = $objs['pipeline/PL_NYC_PAYROLL_LOAD_AND_SUMMARY']
if (-not $pl) { Fail 'Missing pipeline' } else {
    $acts = @{}; $pl.properties.activities | ForEach-Object { $acts[$_.name] = $_ }
    foreach ($a in $acts.Values) {
        if ($a.type -ne 'ExecuteDataFlow') { Fail "$($a.name) not ExecuteDataFlow" }
        if (-not $objs["dataflow/$($a.typeProperties.dataflow.referenceName)"]) { Fail "$($a.name) references unknown data flow" }
        foreach ($dep in $a.dependsOn) {
            if (-not $acts[$dep.activity]) { Fail "$($a.name) depends on unknown activity $($dep.activity)" }
            if ($dep.dependencyConditions -notcontains 'Succeeded') { Fail "$($a.name) dependency not Succeeded" }
        }
    }
    $p = $acts['Build Payroll Summary'].typeProperties.dataflow.parameters.dataflow_param_fiscalyear.value
    if ($p -ne '@pipeline().globalParameters.global_param_fiscalyear') { Fail "Global parameter expression is '$p'" } else { Ok 'Global parameter expression correct' }
    Ok "Pipeline has $($acts.Count) ExecuteDataFlow activities"
}

$pat = 'AccountKey=|SharedAccessSignature|sig=|Password\s*=(?!\s*['']?<)|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|\bsv=20'
$hits = Get-ChildItem $root -Recurse -File -Include *.json,*.sql,*.md,*.ps1 | Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.Name -ne 'validate-adf.ps1' } | Select-String -Pattern $pat
if ($hits) { $hits | ForEach-Object { Fail "Possible secret: $($_.Path):$($_.LineNumber)" } } else { Ok 'No secret patterns found' }

if ($errors.Count) { Write-Host "`n$($errors.Count) problem(s)" -ForegroundColor Red; exit 1 } else { Write-Host "`nAll checks passed" -ForegroundColor Green }
