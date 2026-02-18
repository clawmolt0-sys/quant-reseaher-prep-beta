# Rebuild per-category JSON chunks from problems.json
# Only include complete problems in chunks (chunks are for detail view)

$problemsPath = "$PSScriptRoot\..\data\problems.json"
$chunksDir = "$PSScriptRoot\..\data\problems"

Write-Host "Loading problems.json..."
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json

# Group by category, only include complete problems
$categories = @{}
foreach ($p in $problems) {
    if ($p.status -ne 'complete') { continue }
    $cat = $p.category
    if (-not $cat) { continue }
    if (-not $categories.ContainsKey($cat)) { $categories[$cat] = @() }
    $categories[$cat] += $p
}

Write-Host "Writing $($categories.Count) category chunks..."
foreach ($entry in $categories.GetEnumerator()) {
    $cat = $entry.Key
    $probs = $entry.Value
    $path = "$chunksDir\$cat.json"
    $probs | ConvertTo-Json -Depth 10 -Compress | Set-Content $path -Encoding UTF8
    $size = [math]::Round((Get-Item $path).Length / 1KB, 1)
    Write-Host "  ${cat}: $($probs.Count) problems, ${size} KB"
}

Write-Host ""
Write-Host "Done. $($categories.Count) chunks written."
