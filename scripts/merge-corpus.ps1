# Merge ingested corpus data into main problems.json
# Deduplicates against existing problems by title/statement similarity
# Assigns new IDs, adds new companies

param(
    [switch]$DryRun = $false
)

$dataDir = "$PSScriptRoot\..\data"
$ingestDir = "$dataDir\ingest"
$problemsPath = "$dataDir\problems.json"
$companiesPath = "$dataDir\companies.json"

# ============ LOAD EXISTING DATA ============
Write-Output "Loading existing problems..."
$existing = Get-Content $problemsPath -Raw | ConvertFrom-Json
$maxId = ($existing | Measure-Object -Property id -Maximum).Maximum
Write-Output "  Existing problems: $($existing.Count), max ID: $maxId"

Write-Output "Loading existing companies..."
$companies = Get-Content $companiesPath -Raw | ConvertFrom-Json
$existingCompanySlugs = @{}
foreach ($c in $companies) { $existingCompanySlugs[$c.id] = $true }

# Build fingerprint set for dedup (normalized title + first 100 chars of statement)
function Get-Fingerprint($title, $statement) {
    $t = ($title -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', ' ').Trim().ToLower()
    $s = ($statement -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', ' ').Trim().ToLower()
    $sShort = if ($s.Length -gt 100) { $s.Substring(0, 100) } else { $s }
    return "$t|||$sShort"
}

$existingFingerprints = @{}
foreach ($p in $existing) {
    $fp = Get-Fingerprint $p.title $p.statement
    $existingFingerprints[$fp] = $p.id
    # Also store just the title for fuzzy matching
    $titleNorm = ($p.title -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', ' ').Trim().ToLower()
    $existingFingerprints["title:$titleNorm"] = $p.id
}

# ============ LOAD INGESTED DATA ============
$sources = @("openquant-converted.json", "quantable-converted.json", "glassdoor-converted.json")
$allNew = @()

foreach ($src in $sources) {
    $path = "$ingestDir\$src"
    if (Test-Path $path) {
        $data = Get-Content $path -Raw | ConvertFrom-Json
        Write-Output "  Loaded $src`: $($data.Count) problems"
        $allNew += $data
    } else {
        Write-Output "  SKIP $src (not found)"
    }
}

Write-Output "Total new candidates: $($allNew.Count)"

# ============ DEDUPLICATE ============
$nextId = $maxId + 1
$added = @()
$skippedDup = 0
$skippedEmpty = 0
$newCompanies = @{}

foreach ($p in $allNew) {
    # Skip empty
    if (-not $p.statement -or $p.statement.Length -lt 30) {
        $skippedEmpty++
        continue
    }

    # Check fingerprint
    $fp = Get-Fingerprint $p.title $p.statement
    $titleNorm = ($p.title -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', ' ').Trim().ToLower()

    if ($existingFingerprints.ContainsKey($fp) -or $existingFingerprints.ContainsKey("title:$titleNorm")) {
        $skippedDup++
        continue
    }

    # Assign new ID
    $p.id = $nextId
    $nextId++

    # Track fingerprint to prevent intra-corpus duplicates
    $existingFingerprints[$fp] = $p.id
    $existingFingerprints["title:$titleNorm"] = $p.id

    # Track new companies
    foreach ($comp in $p.companies) {
        if (-not $existingCompanySlugs.ContainsKey($comp) -and -not $newCompanies.ContainsKey($comp)) {
            $newCompanies[$comp] = $true
        }
    }

    $added += $p
}

Write-Output ""
Write-Output "========================================="
Write-Output "MERGE RESULTS:"
Write-Output "  Added: $($added.Count)"
Write-Output "  Skipped (duplicate): $skippedDup"
Write-Output "  Skipped (empty): $skippedEmpty"
Write-Output "  New companies found: $($newCompanies.Count)"
Write-Output "  ID range: $($maxId + 1) - $($nextId - 1)"
Write-Output "========================================="

# Source breakdown
$sourceBreakdown = $added | Group-Object source | Select-Object Name, Count
Write-Output ""
Write-Output "By source:"
foreach ($g in $sourceBreakdown) {
    Write-Output "  $($g.Name): $($g.Count)"
}

# Status breakdown
$statusBreakdown = $added | Group-Object status | Select-Object Name, Count
Write-Output ""
Write-Output "By status:"
foreach ($g in $statusBreakdown) {
    Write-Output "  $($g.Name): $($g.Count)"
}

# Category breakdown
$catBreakdown = $added | Group-Object category | Sort-Object Count -Descending | Select-Object Name, Count
Write-Output ""
Write-Output "By category:"
foreach ($g in $catBreakdown) {
    Write-Output "  $($g.Name): $($g.Count)"
}

if ($newCompanies.Count -gt 0) {
    Write-Output ""
    Write-Output "New companies to add:"
    foreach ($c in $newCompanies.Keys | Sort-Object) {
        Write-Output "  $c"
    }
}

if ($DryRun) {
    Write-Output ""
    Write-Output "[DRY RUN] No files modified."
    return
}

# ============ SAVE ============
# Add new companies
foreach ($comp in ($newCompanies.Keys | Sort-Object)) {
    $displayName = ($comp -replace '-', ' ') -replace '\b(\w)', { $_.Groups[1].Value.ToUpper() }
    $companies += [PSCustomObject]@{
        id = $comp
        name = $displayName
        type = "Trading Firm"
        roles = @("Quant")
    }
}

Write-Output ""
Write-Output "Saving companies.json..."
$companies | ConvertTo-Json -Depth 5 | Set-Content $companiesPath -Encoding UTF8

# Merge problems
$merged = @()
$merged += $existing
$merged += $added

Write-Output "Saving problems.json ($($merged.Count) problems)..."
$merged | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8

$fileSize = [math]::Round((Get-Item $problemsPath).Length / 1KB)
Write-Output "Done. File size: ${fileSize} KB"
Write-Output "Total problems: $($merged.Count)"
