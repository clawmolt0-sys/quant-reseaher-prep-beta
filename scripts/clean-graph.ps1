# Clean the similarity graph to only reference complete problems
# Remove edges that point to incomplete/title-only/duplicate problems

$graphPath = "$PSScriptRoot\..\data\similarity-graph.json"
$problemsPath = "$PSScriptRoot\..\data\problems.json"

[Console]::Out.WriteLine("Loading data...")
$graph = Get-Content $graphPath -Raw | ConvertFrom-Json
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json

# Build set of complete problem IDs
$completeIds = @{}
foreach ($p in $problems) {
    if ($p.status -eq 'complete') {
        $completeIds[$p.id] = $true
    }
}
[Console]::Out.WriteLine("Complete problems: $($completeIds.Count)")

# Clean edges: only keep edges from/to complete problems
$edgeKeys = $graph.edges.PSObject.Properties.Name
$removedNodes = 0
$removedEdges = 0
$keptEdges = 0

$newEdges = [ordered]@{}
foreach ($key in $edgeKeys) {
    $srcId = [int]$key
    if (-not $completeIds.ContainsKey($srcId)) {
        $removedNodes++
        continue
    }

    $edges = $graph.edges.$key
    $filtered = @()
    foreach ($e in $edges) {
        if ($completeIds.ContainsKey($e.id)) {
            $filtered += $e
            $keptEdges++
        } else {
            $removedEdges++
        }
    }

    if ($filtered.Count -gt 0) {
        $newEdges[$key] = $filtered
    }
}

# Update graph
$graph.edges = [PSCustomObject]$newEdges
$graph._meta.problemCount = $completeIds.Count
$graph._meta.edgeCount = $keptEdges

# Also clean concepts: only list complete problem IDs
$conceptKeys = $graph.concepts.PSObject.Properties.Name
foreach ($ckey in $conceptKeys) {
    $concept = $graph.concepts.$ckey
    $cleanProblems = @($concept.problems | Where-Object { $completeIds.ContainsKey($_) })
    $concept.problems = $cleanProblems
}

[Console]::Out.WriteLine("Removed $removedNodes source nodes (not complete)")
[Console]::Out.WriteLine("Removed $removedEdges edges to non-complete problems")
[Console]::Out.WriteLine("Kept $keptEdges edges")
[Console]::Out.WriteLine("Remaining nodes: $($newEdges.Count)")

[Console]::Out.WriteLine("Saving cleaned graph...")
$graph | ConvertTo-Json -Depth 10 -Compress | Set-Content $graphPath -Encoding UTF8
$size = [math]::Round((Get-Item $graphPath).Length / 1KB, 1)
[Console]::Out.WriteLine("Done. File size: ${size} KB")
