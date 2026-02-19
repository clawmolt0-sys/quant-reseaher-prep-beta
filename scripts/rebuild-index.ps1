# Rebuild problems-index.json from problems.json
# Index fields: id, t (title), c (category), d (difficulty), y (type), s (status), co (companies), tg (tags), ro (roles)

$problemsPath = "$PSScriptRoot\..\data\problems.json"
$indexPath = "$PSScriptRoot\..\data\problems-index.json"

Write-Host "Loading problems.json..."
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json

Write-Host "Building index..."
$index = @()
foreach ($p in $problems) {
    $entry = [ordered]@{
        id = $p.id
        t  = $p.title
        c  = $p.category
        d  = $p.difficulty
        y  = $p.type
        s  = $p.status
        co = @($p.companies)
        tg = @($p.tags)
        ro = @($p.roles)
    }
    $index += [PSCustomObject]$entry
}

# Sort by ID
$index = $index | Sort-Object { $_.id }

Write-Host "Saving problems-index.json..."
$index | ConvertTo-Json -Depth 5 -Compress | Set-Content $indexPath -Encoding UTF8

$fileSize = (Get-Item $indexPath).Length / 1KB
Write-Host "Done. Index has $($index.Count) entries, file size: $([math]::Round($fileSize, 1)) KB"

# Status distribution
$statuses = @{}
foreach ($p in $index) {
    $s = $p.s
    if (-not $statuses.ContainsKey($s)) { $statuses[$s] = 0 }
    $statuses[$s]++
}
Write-Host ""
Write-Host "Status distribution:"
foreach ($entry in ($statuses.GetEnumerator() | Sort-Object Value -Descending)) {
    Write-Host "  $($entry.Key): $($entry.Value)"
}
