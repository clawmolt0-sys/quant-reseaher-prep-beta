# Apply ALL generated solutions from all batch files back into problems.json
# Reads all solution files and merges them

$dataDir = "$PSScriptRoot\..\data"
$problemsPath = "$dataDir\problems.json"
$ingestDir = "$dataDir\ingest"

[Console]::Out.WriteLine("Loading problems.json...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
[Console]::Out.WriteLine("  Total: $($problems.Count)")

# Build lookup by ID
$lookup = @{}
for ($i = 0; $i -lt $problems.Count; $i++) {
    $lookup[$problems[$i].id] = $i
}

# Find all solution files
$solutionFiles = Get-ChildItem "$ingestDir\solutions-*.json" -ErrorAction SilentlyContinue
[Console]::Out.WriteLine("Found $($solutionFiles.Count) solution files")

$totalApplied = 0

foreach ($file in $solutionFiles) {
    $solutions = Get-Content $file.FullName -Raw | ConvertFrom-Json
    $applied = 0

    foreach ($sol in $solutions) {
        $idx = $lookup[$sol.id]
        if ($null -ne $idx) {
            $p = $problems[$idx]
            if ($p.status -eq 'incomplete' -and $sol.solution -and $sol.solution.Length -gt 50) {
                $p.solution = $sol.solution
                $p.status = "complete"
                $applied++
            }
        }
    }

    [Console]::Out.WriteLine("  $($file.Name): $($solutions.Count) solutions, $applied newly applied")
    $totalApplied += $applied
}

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Total solutions newly applied: $totalApplied")

# Count final statuses
$statuses = $problems | Group-Object status
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Final status breakdown:")
foreach ($s in ($statuses | Sort-Object Count -Descending)) {
    [Console]::Out.WriteLine("  $($s.Name): $($s.Count)")
}

# Save
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Saving problems.json...")
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8
$size = [math]::Round((Get-Item $problemsPath).Length / 1KB)
[Console]::Out.WriteLine("Done. File size: ${size} KB")
