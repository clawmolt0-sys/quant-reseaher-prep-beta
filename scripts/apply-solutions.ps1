# Apply generated solutions from batch files back into problems.json
# Reads solutions-batch{1-4}.json and merges them into the main file

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

# Load and apply each batch
$totalApplied = 0
$batches = @("solutions-batch1.json", "solutions-batch2.json", "solutions-batch3.json", "solutions-batch4.json")

foreach ($batch in $batches) {
    $path = "$ingestDir\$batch"
    if (-not (Test-Path $path)) {
        [Console]::Out.WriteLine("  SKIP $batch (not found)")
        continue
    }

    $solutions = Get-Content $path -Raw | ConvertFrom-Json
    $applied = 0

    foreach ($sol in $solutions) {
        $idx = $lookup[$sol.id]
        if ($null -ne $idx) {
            $p = $problems[$idx]
            if ($sol.solution -and $sol.solution.Length -gt 50) {
                $p.solution = $sol.solution
                $p.status = "complete"
                $applied++
            }
        }
    }

    [Console]::Out.WriteLine("  $batch`: $($solutions.Count) solutions, $applied applied")
    $totalApplied += $applied
}

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Total solutions applied: $totalApplied")

# Count final statuses
$statuses = $problems | Group-Object status
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Final status breakdown:")
foreach ($s in $statuses) {
    [Console]::Out.WriteLine("  $($s.Name): $($s.Count)")
}

# Save
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Saving problems.json...")
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8
$size = [math]::Round((Get-Item $problemsPath).Length / 1KB)
[Console]::Out.WriteLine("Done. File size: ${size} KB")
[Console]::Out.WriteLine("Total problems: $($problems.Count)")
