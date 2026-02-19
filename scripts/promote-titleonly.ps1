# Promote title-only problems that actually have statements to incomplete
# And check if any have both statement+solution that should be complete
$problemsPath = "$PSScriptRoot\..\data\problems.json"
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json

$promoted = 0
$toComplete = 0
foreach ($p in $problems) {
    if ($p.status -eq 'title-only') {
        if ($p.statement -and $p.statement.Length -gt 20) {
            if ($p.solution -and $p.solution.Length -gt 30) {
                $p.status = 'complete'
                $toComplete++
            } else {
                $p.status = 'incomplete'
                $promoted++
            }
        }
    }
}

[Console]::Out.WriteLine("Promoted title-only -> incomplete: $promoted")
[Console]::Out.WriteLine("Promoted title-only -> complete: $toComplete")

$statuses = $problems | Group-Object status | Sort-Object Count -Descending
foreach ($s in $statuses) { [Console]::Out.WriteLine("  $($s.Name): $($s.Count)") }

$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8
[Console]::Out.WriteLine("Saved.")
