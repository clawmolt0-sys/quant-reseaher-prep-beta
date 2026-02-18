# Solve or mark the final 30 incomplete problems
$problemsPath = "$PSScriptRoot\..\data\problems.json"
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json

$lookup = @{}
for ($i = 0; $i -lt $problems.Count; $i++) {
    $lookup[$problems[$i].id] = $i
}

# Problems too vague/behavioral to be real interview quant problems - mark as duplicate
$tooVague = @(2748, 2751, 2752, 2756, 2757, 2758, 2761, 2764, 2769)

foreach ($id in $tooVague) {
    $idx = $lookup[$id]
    if ($null -ne $idx) {
        $problems[$idx].status = "duplicate"
        [Console]::Out.WriteLine("Marked $id as duplicate (too vague)")
    }
}

# Load solutions from JSON file
$solPath = "$PSScriptRoot\..\data\ingest\solutions-final30.json"
if (Test-Path $solPath) {
    $sols = Get-Content $solPath -Raw | ConvertFrom-Json
    foreach ($sol in $sols) {
        $idx = $lookup[$sol.id]
        if ($null -ne $idx -and $problems[$idx].status -eq 'incomplete') {
            $problems[$idx].solution = $sol.solution
            $problems[$idx].status = "complete"
            [Console]::Out.WriteLine("Solved ID $($sol.id): $($problems[$idx].title)")
        }
    }
}

# Save
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8

# Final stats
[Console]::Out.WriteLine("")
$statuses = $problems | Group-Object status
foreach ($s in ($statuses | Sort-Object Count -Descending)) {
    [Console]::Out.WriteLine("  $($s.Name): $($s.Count)")
}
$size = [math]::Round((Get-Item $problemsPath).Length / 1KB)
[Console]::Out.WriteLine("File size: ${size} KB")
