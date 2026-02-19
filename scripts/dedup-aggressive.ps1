# Aggressive dedup across ALL problems using:
# 1. Graph edges (for complete problems in the knowledge graph)
# 2. Title similarity (Jaccard + normalized fingerprint)
# 3. Statement prefix matching
# 4. Cross-category scanning for concept-level duplicates

$dataDir = "$PSScriptRoot\..\data"
$problemsPath = "$dataDir\problems.json"
$graphPath = "$dataDir\similarity-graph.json"

[Console]::Out.WriteLine("Loading data...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
$graph = Get-Content $graphPath -Raw | ConvertFrom-Json
[Console]::Out.WriteLine("  Problems: $($problems.Count)")

# Build lookup
$problemById = @{}
$problemIdx = @{}
for ($i = 0; $i -lt $problems.Count; $i++) {
    $problemById[$problems[$i].id] = $problems[$i]
    $problemIdx[$problems[$i].id] = $i
}

$pairs = @{}
$totalDups = 0
$companyMerges = 0
$solCopies = 0

function Get-SolutionQuality($p) {
    if (-not $p.solution -or $p.solution.Length -lt 50) { return 0 }
    $score = [math]::Min($p.solution.Length / 500.0, 1.0)
    if ($p.solution -match '\$') { $score += 0.1 }
    if ($p.solution -match '##|Step|\\begin') { $score += 0.1 }
    if ($p.status -eq 'complete') { $score += 0.5 }
    return [math]::Round($score, 2)
}

function Mark-Duplicate($keeper, $dup) {
    $pairKey = "$([math]::Min($keeper.id, $dup.id))-$([math]::Max($keeper.id, $dup.id))"
    if ($script:pairs.ContainsKey($pairKey)) { return $false }
    $script:pairs[$pairKey] = $true

    # Merge companies
    if ($dup.companies) {
        foreach ($c in $dup.companies) {
            if ($c -notin @($keeper.companies)) {
                $keeper.companies = @($keeper.companies) + $c
                $script:companyMerges++
            }
        }
    }
    # Copy solution if keeper lacks one
    if ((-not $keeper.solution -or $keeper.solution.Length -lt 50) -and $dup.solution -and $dup.solution.Length -gt 50) {
        $keeper.solution = $dup.solution
        if ($keeper.status -ne 'complete') { $keeper.status = 'complete' }
        $script:solCopies++
    }
    # Copy tags
    if ($dup.tags) {
        foreach ($t in $dup.tags) {
            if ($t -and $t -notin @($keeper.tags)) { $keeper.tags = @($keeper.tags) + $t }
        }
    }

    $idx = $script:problemIdx[$dup.id]
    $script:problems[$idx].status = 'duplicate'
    $script:totalDups++
    return $true
}

# ============ PHASE 1: Graph-based dedup (complete problems) ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Phase 1: Graph-based dedup...")

$edgeKeys = @($graph.edges.PSObject.Properties.Name)
$graphDups = 0

foreach ($nodeKey in $edgeKeys) {
    $nodeId = [int]$nodeKey
    $p1 = $problemById[$nodeId]
    if (-not $p1 -or $p1.status -eq 'duplicate') { continue }

    $edges = @($graph.edges.$nodeKey)
    foreach ($e in $edges) {
        if ($e.w -lt 0.80) { continue }
        $p2 = $problemById[$e.id]
        if (-not $p2 -or $p2.status -eq 'duplicate') { continue }

        # Compute title Jaccard
        $w1 = @($p1.title.ToLower() -split '[^a-zA-Z0-9]+' | Where-Object { $_.Length -gt 2 })
        $w2 = @($p2.title.ToLower() -split '[^a-zA-Z0-9]+' | Where-Object { $_.Length -gt 2 })
        if ($w1.Count -eq 0 -or $w2.Count -eq 0) { continue }
        $s1 = @{}; foreach ($w in $w1) { $s1[$w] = $true }
        $s2 = @{}; foreach ($w in $w2) { $s2[$w] = $true }
        $inter = 0; foreach ($w in $s1.Keys) { if ($s2.ContainsKey($w)) { $inter++ } }
        $union = $s1.Count + $s2.Count - $inter
        $titleJac = if ($union -gt 0) { [math]::Round($inter / $union, 3) } else { 0 }

        # Decision with LOOSER thresholds than before
        $isDup = $false
        if ($e.w -ge 0.95 -and $titleJac -ge 0.7) { $isDup = $true }
        elseif ($e.w -ge 0.90 -and $titleJac -ge 0.55) { $isDup = $true }
        elseif ($e.w -ge 0.85 -and $titleJac -ge 0.7) { $isDup = $true }
        elseif ($titleJac -ge 0.9) { $isDup = $true }

        if ($isDup) {
            $q1 = Get-SolutionQuality $p1
            $q2 = Get-SolutionQuality $p2
            $keeper = if ($q1 -ge $q2) { $p1 } else { $p2 }
            $dup = if ($q1 -ge $q2) { $p2 } else { $p1 }
            if (Mark-Duplicate $keeper $dup) {
                $graphDups++
                if ($graphDups -le 20 -or $graphDups % 50 -eq 0) {
                    [Console]::Out.WriteLine("  GRAPH DUP #${graphDups}: ID $($dup.id) -> ID $($keeper.id) (w=$($e.w), jac=$titleJac)")
                }
            }
        }
    }
}
[Console]::Out.WriteLine("  Graph duplicates: $graphDups")

# ============ PHASE 2: Title fingerprint dedup (all problems) ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Phase 2: Title fingerprint dedup...")

$titleFp = @{}
$fpDups = 0
foreach ($p in ($problems | Sort-Object { -(Get-SolutionQuality $_) }, { $_.id })) {
    if ($p.status -eq 'duplicate') { continue }

    $fp = ($p.title.ToLower() -replace '[^a-z0-9]', '').Trim()
    if ($fp.Length -le 8) { continue }

    if ($titleFp.ContainsKey($fp)) {
        $keeper = $titleFp[$fp]
        if (Mark-Duplicate $keeper $p) {
            $fpDups++
            if ($fpDups -le 20 -or $fpDups % 50 -eq 0) {
                $titleShort = if ($p.title.Length -gt 50) { $p.title.Substring(0, 47) + '...' } else { $p.title }
                [Console]::Out.WriteLine("  FP DUP #${fpDups}: ID $($p.id) '$titleShort' -> ID $($keeper.id)")
            }
        }
    } else {
        $titleFp[$fp] = $p
    }
}
[Console]::Out.WriteLine("  Fingerprint duplicates: $fpDups")

# ============ PHASE 3: Statement prefix dedup (all problems) ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Phase 3: Statement prefix dedup...")

$stmtFp = @{}
$stmtDups = 0
foreach ($p in ($problems | Sort-Object { -(Get-SolutionQuality $_) }, { $_.id })) {
    if ($p.status -eq 'duplicate') { continue }
    if (-not $p.statement -or $p.statement.Length -lt 40) { continue }

    $norm = $p.statement.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
    $norm = $norm.Trim()
    if ($norm.Length -lt 30) { continue }

    $prefix = $norm.Substring(0, [math]::Min(80, $norm.Length))

    if ($stmtFp.ContainsKey($prefix)) {
        $keeper = $stmtFp[$prefix]
        if (Mark-Duplicate $keeper $p) {
            $stmtDups++
            if ($stmtDups -le 20 -or $stmtDups % 50 -eq 0) {
                [Console]::Out.WriteLine("  STMT DUP #${stmtDups}: ID $($p.id) -> ID $($keeper.id)")
            }
        }
    } else {
        $stmtFp[$prefix] = $p
    }
}
[Console]::Out.WriteLine("  Statement prefix duplicates: $stmtDups")

# ============ PHASE 4: Cross-category title Jaccard (catch concept-level dups) ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Phase 4: Cross-category title Jaccard dedup...")

# Build word sets for non-dup problems
$allWordSets = @()
foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    $words = @($p.title.ToLower() -split '[^a-zA-Z0-9]+' | Where-Object { $_.Length -gt 2 })
    if ($words.Count -ge 3) {
        $allWordSets += @{ problem = $p; words = $words; wordSet = @{} }
        foreach ($w in $words) { $allWordSets[-1].wordSet[$w] = $true }
    }
}

[Console]::Out.WriteLine("  Comparing $($allWordSets.Count) problems...")

$crossDups = 0
# Sort by word count ascending to make shorter titles match against longer ones
$allWordSets = @($allWordSets | Sort-Object { $_.words.Count })

for ($i = 0; $i -lt $allWordSets.Count; $i++) {
    $a = $allWordSets[$i]
    if ($a.problem.status -eq 'duplicate') { continue }

    for ($j = $i + 1; $j -lt $allWordSets.Count; $j++) {
        $b = $allWordSets[$j]
        if ($b.problem.status -eq 'duplicate') { continue }

        # Quick filter: at least 3 words in common
        $commonCount = 0
        foreach ($w in $a.wordSet.Keys) {
            if ($b.wordSet.ContainsKey($w)) { $commonCount++ }
        }
        if ($commonCount -lt 3) { continue }

        # Compute Jaccard
        $union = $a.wordSet.Count + $b.wordSet.Count - $commonCount
        $jac = if ($union -gt 0) { [math]::Round($commonCount / $union, 3) } else { 0 }

        if ($jac -ge 0.8) {
            # Also verify statement similarity
            $s1 = if ($a.problem.statement) { $a.problem.statement } else { '' }
            $s2 = if ($b.problem.statement) { $b.problem.statement } else { '' }
            if ($s1.Length -gt 30 -and $s2.Length -gt 30) {
                $n1 = $s1.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
                $n2 = $s2.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
                $n1 = $n1.Trim(); $n2 = $n2.Trim()
                $len = [math]::Min(120, [math]::Min($n1.Length, $n2.Length))
                $matches = 0
                for ($k = 0; $k -lt $len; $k++) { if ($n1[$k] -eq $n2[$k]) { $matches++ } }
                $stmtSim = [math]::Round($matches / [math]::Max(1, $len), 3)

                if ($stmtSim -ge 0.4 -or $jac -ge 0.9) {
                    $q1 = Get-SolutionQuality $a.problem
                    $q2 = Get-SolutionQuality $b.problem
                    $keeper = if ($q1 -ge $q2) { $a.problem } else { $b.problem }
                    $dup = if ($q1 -ge $q2) { $b.problem } else { $a.problem }
                    if (Mark-Duplicate $keeper $dup) {
                        $crossDups++
                        if ($crossDups -le 30 -or $crossDups % 100 -eq 0) {
                            [Console]::Out.WriteLine("  CROSS DUP #${crossDups}: ID $($dup.id) '$($dup.title.Substring(0, [math]::Min(40, $dup.title.Length)))' -> ID $($keeper.id) (jac=$jac, stmt=$stmtSim)")
                        }
                    }
                }
            } elseif ($jac -ge 0.9) {
                # Very high title similarity even without statement check
                $q1 = Get-SolutionQuality $a.problem
                $q2 = Get-SolutionQuality $b.problem
                $keeper = if ($q1 -ge $q2) { $a.problem } else { $b.problem }
                $dup = if ($q1 -ge $q2) { $b.problem } else { $a.problem }
                if (Mark-Duplicate $keeper $dup) {
                    $crossDups++
                    if ($crossDups -le 30 -or $crossDups % 100 -eq 0) {
                        [Console]::Out.WriteLine("  CROSS DUP #${crossDups}: ID $($dup.id) -> ID $($keeper.id) (jac=$jac, no stmt)")
                    }
                }
            }
        }
    }
}
[Console]::Out.WriteLine("  Cross-category duplicates: $crossDups")

# ============ REPORT ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("AGGRESSIVE DEDUP RESULTS:")
[Console]::Out.WriteLine("  Graph-based: $graphDups")
[Console]::Out.WriteLine("  Title fingerprint: $fpDups")
[Console]::Out.WriteLine("  Statement prefix: $stmtDups")
[Console]::Out.WriteLine("  Cross-category title Jaccard: $crossDups")
[Console]::Out.WriteLine("  TOTAL NEW DUPS: $totalDups")
[Console]::Out.WriteLine("  Companies merged: $companyMerges")
[Console]::Out.WriteLine("  Solutions copied: $solCopies")
[Console]::Out.WriteLine("=========================================")

$statuses = $problems | Group-Object status | Sort-Object Count -Descending
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Final status breakdown:")
foreach ($s in $statuses) { [Console]::Out.WriteLine("  $($s.Name): $($s.Count)") }

# Save
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Saving...")
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8
$size = [math]::Round((Get-Item $problemsPath).Length / 1KB)
[Console]::Out.WriteLine("Done. File size: ${size} KB")
