# Fix duplicate company slugs in problems.json and companies.json
# Consolidates jp-morgan -> jpmorgan, cutler-group-llc -> cutler-group, etc.

$dataDir = "$PSScriptRoot\..\data"
$problemsPath = "$dataDir\problems.json"
$companiesPath = "$dataDir\companies.json"

# Slug mappings: old -> canonical
$slugMap = @{
    "jp-morgan" = "jpmorgan"
    "cutler-group-llc" = "cutler-group"
}

# Fix problems
[Console]::Out.WriteLine("Loading problems...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
$fixedCount = 0

foreach ($p in $problems) {
    if ($p.companies) {
        $newComps = @()
        $changed = $false
        foreach ($c in $p.companies) {
            if ($slugMap.ContainsKey($c)) {
                $newComps += $slugMap[$c]
                $changed = $true
            } else {
                $newComps += $c
            }
        }
        if ($changed) {
            # Deduplicate
            $p.companies = @($newComps | Sort-Object -Unique)
            $fixedCount++
        }
    }
}
[Console]::Out.WriteLine("Fixed $fixedCount problems with duplicate company slugs")

# Save problems
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8

# Fix companies
[Console]::Out.WriteLine("Loading companies...")
$companies = Get-Content $companiesPath -Raw | ConvertFrom-Json

# Remove duplicate company entries
$seen = @{}
$cleaned = @()
foreach ($c in $companies) {
    $canonical = if ($slugMap.ContainsKey($c.id)) { $slugMap[$c.id] } else { $c.id }
    if (-not $seen.ContainsKey($canonical)) {
        $seen[$canonical] = $true
        if ($c.id -ne $canonical) {
            $c.id = $canonical
        }
        $cleaned += $c
    }
}

$removed = $companies.Count - $cleaned.Count
[Console]::Out.WriteLine("Removed $removed duplicate company entries")
[Console]::Out.WriteLine("Total companies: $($cleaned.Count)")

$cleaned | ConvertTo-Json -Depth 5 | Set-Content $companiesPath -Encoding UTF8
[Console]::Out.WriteLine("Done.")
