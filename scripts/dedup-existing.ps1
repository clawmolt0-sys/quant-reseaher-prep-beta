# Graph-based deduplication of existing problems
# Uses the knowledge graph similarity edges + title Jaccard + statement prefix matching
# to identify and mark duplicates in the current database

$dataDir = "$PSScriptRoot\..\data"
$problemsPath = "$dataDir\problems.json"
$graphPath = "$dataDir\similarity-graph.json"

[Console]::Out.WriteLine("Loading data...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
$graph = Get-Content $graphPath -Raw | ConvertFrom-Json
[Console]::Out.WriteLine("  Problems: $($problems.Count)")
[Console]::Out.WriteLine("  Graph nodes: $($graph.edges.PSObject.Properties.Name.Count)")

# Build lookup
$problemById = @{}
$problemIdx = @{}
for ($i = 0; $i -lt $problems.Count; $i++) {
    $p = $problems[$i]
    $problemById[$p.id] = $p
    $problemIdx[$p.id] = $i
}

# ============ SIMILARITY FUNCTIONS ============

function Get-TitleJaccard($t1, $t2) {
    if (-not $t1 -or -not $t2) { return 0 }
    $words1 = @($t1.ToLower() -split '[^a-zA-Z0-9]+' | Where-Object { $_.Length -gt 2 })
    $words2 = @($t2.ToLower() -split '[^a-zA-Z0-9]+' | Where-Object { $_.Length -gt 2 })
    if ($words1.Count -eq 0 -or $words2.Count -eq 0) { return 0 }

    $set1 = @{}; foreach ($w in $words1) { $set1[$w] = $true }
    $set2 = @{}; foreach ($w in $words2) { $set2[$w] = $true }

    $intersection = 0
    foreach ($w in $set1.Keys) { if ($set2.ContainsKey($w)) { $intersection++ } }
    $union = $set1.Count + $set2.Count - $intersection

    if ($union -eq 0) { return 0 }
    return [math]::Round($intersection / $union, 3)
}

function Get-StatementSimilarity($s1, $s2) {
    if (-not $s1 -or -not $s2) { return 0 }
    # Normalize: lowercase, remove latex, remove punctuation, collapse whitespace
    $n1 = $s1.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
    $n2 = $s2.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
    $n1 = $n1.Trim()
    $n2 = $n2.Trim()

    if ($n1.Length -lt 20 -or $n2.Length -lt 20) { return 0 }

    # Compare first 200 chars
    $len = [math]::Min(200, [math]::Min($n1.Length, $n2.Length))
    $sub1 = $n1.Substring(0, $len)
    $sub2 = $n2.Substring(0, $len)

    # Character-level match
    $matches = 0
    for ($i = 0; $i -lt $len; $i++) {
        if ($sub1[$i] -eq $sub2[$i]) { $matches++ }
    }
    return [math]::Round($matches / $len, 3)
}

function Get-SolutionQuality($p) {
    if (-not $p.solution -or $p.solution.Length -lt 50) { return 0 }
    $score = [math]::Min($p.solution.Length / 500.0, 1.0)
    # Bonus for LaTeX
    if ($p.solution -match '\$') { $score += 0.1 }
    # Bonus for structure
    if ($p.solution -match '##|Step|\\begin') { $score += 0.1 }
    return [math]::Round($score, 2)
}

# ============ SCAN GRAPH FOR HIGH-SIMILARITY PAIRS ============

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Scanning graph for high-similarity pairs...")

$pairs = @{}  # Track unique pairs to avoid processing both directions
$autoMerged = 0
$likelyDup = 0
$flagged = 0
$companiesMerged = 0
$solutionsCopied = 0

# Also do a title-based scan for problems NOT in graph
[Console]::Out.WriteLine("Building title fingerprint index...")
$titleFingerprint = @{}
foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    $fp = ($p.title.ToLower() -replace '[^a-z0-9]', '')
    if ($fp.Length -gt 5) {
        if (-not $titleFingerprint.ContainsKey($fp)) { $titleFingerprint[$fp] = @() }
        $titleFingerprint[$fp] += $p.id
    }
}

# Find exact title duplicates not in graph
$exactTitleDups = 0
foreach ($fp in $titleFingerprint.Keys) {
    $ids = @($titleFingerprint[$fp])
    if ($ids.Count -gt 1) {
        # Multiple problems with same normalized title
        $probs = @($ids | ForEach-Object { $problemById[$_] } | Where-Object { $_.status -ne 'duplicate' })
        if ($probs.Count -gt 1) {
            # Keep the best one (best solution quality, then lowest ID)
            $sorted = @($probs | Sort-Object { -(Get-SolutionQuality $_) }, { $_.id })
            $keeper = $sorted[0]
            for ($i = 1; $i -lt $sorted.Count; $i++) {
                $dup = $sorted[$i]
                $pairKey = "$([math]::Min($keeper.id, $dup.id))-$([math]::Max($keeper.id, $dup.id))"
                if ($pairs.ContainsKey($pairKey)) { continue }
                $pairs[$pairKey] = $true

                # Merge companies
                if ($dup.companies) {
                    foreach ($c in $dup.companies) {
                        if ($c -notin $keeper.companies) {
                            $keeper.companies = @($keeper.companies) + $c
                            $companiesMerged++
                        }
                    }
                }
                # Copy solution if keeper lacks one
                if ((-not $keeper.solution -or $keeper.solution.Length -lt 50) -and $dup.solution -and $dup.solution.Length -gt 50) {
                    $keeper.solution = $dup.solution
                    if ($keeper.status -eq 'incomplete' -or $keeper.status -eq 'title-only') {
                        $keeper.status = 'complete'
                    }
                    $solutionsCopied++
                }

                # Mark as duplicate
                $idx = $problemIdx[$dup.id]
                $problems[$idx].status = 'duplicate'
                $exactTitleDups++
                [Console]::Out.WriteLine("  EXACT TITLE DUP: ID $($dup.id) '$($dup.title)' -> kept ID $($keeper.id)")
            }
        }
    }
}
[Console]::Out.WriteLine("Exact title duplicates found: $exactTitleDups")

# Now scan the graph edges
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Scanning graph edges for near-duplicates...")

$edgeKeys = @($graph.edges.PSObject.Properties.Name)
$processedEdges = 0

foreach ($nodeKey in $edgeKeys) {
    $nodeId = [int]$nodeKey
    $p1 = $problemById[$nodeId]
    if (-not $p1 -or $p1.status -eq 'duplicate') { continue }

    $edges = @($graph.edges.$nodeKey)
    foreach ($e in $edges) {
        if ($e.w -lt 0.8) { continue }  # Only high-similarity edges

        $targetId = $e.id
        $pairKey = "$([math]::Min($nodeId, $targetId))-$([math]::Max($nodeId, $targetId))"
        if ($pairs.ContainsKey($pairKey)) { continue }
        $pairs[$pairKey] = $true

        $p2 = $problemById[$targetId]
        if (-not $p2 -or $p2.status -eq 'duplicate') { continue }

        $graphScore = $e.w
        $titleJac = Get-TitleJaccard $p1.title $p2.title
        $stmtSim = Get-StatementSimilarity $p1.statement $p2.statement

        # Combined score
        $combinedScore = ($graphScore * 0.4) + ($titleJac * 0.35) + ($stmtSim * 0.25)

        $processedEdges++

        # Decision tiers
        if (($graphScore -ge 0.95 -and $titleJac -ge 0.8) -or ($titleJac -ge 0.9 -and $stmtSim -ge 0.85)) {
            # AUTO-MERGE: very high confidence duplicate
            $q1 = Get-SolutionQuality $p1
            $q2 = Get-SolutionQuality $p2
            $keeper = if ($q1 -ge $q2) { $p1 } else { $p2 }
            $dup = if ($q1 -ge $q2) { $p2 } else { $p1 }

            # Merge companies
            if ($dup.companies) {
                foreach ($c in $dup.companies) {
                    if ($c -notin $keeper.companies) {
                        $keeper.companies = @($keeper.companies) + $c
                        $companiesMerged++
                    }
                }
            }
            # Copy solution
            if ((-not $keeper.solution -or $keeper.solution.Length -lt 50) -and $dup.solution -and $dup.solution.Length -gt 50) {
                $keeper.solution = $dup.solution
                if ($keeper.status -eq 'incomplete' -or $keeper.status -eq 'title-only') { $keeper.status = 'complete' }
                $solutionsCopied++
            }

            $idx = $problemIdx[$dup.id]
            $problems[$idx].status = 'duplicate'
            $autoMerged++
            [Console]::Out.WriteLine("  AUTO-MERGE: ID $($dup.id) -> kept ID $($keeper.id) (graph=$graphScore, title=$titleJac, stmt=$stmtSim)")
        } elseif (($graphScore -ge 0.90 -and $titleJac -ge 0.6) -or ($titleJac -ge 0.8 -and $stmtSim -ge 0.7)) {
            # LIKELY DUP
            $q1 = Get-SolutionQuality $p1
            $q2 = Get-SolutionQuality $p2
            $keeper = if ($q1 -ge $q2) { $p1 } else { $p2 }
            $dup = if ($q1 -ge $q2) { $p2 } else { $p1 }

            if ($dup.companies) {
                foreach ($c in $dup.companies) {
                    if ($c -notin $keeper.companies) {
                        $keeper.companies = @($keeper.companies) + $c
                        $companiesMerged++
                    }
                }
            }
            if ((-not $keeper.solution -or $keeper.solution.Length -lt 50) -and $dup.solution -and $dup.solution.Length -gt 50) {
                $keeper.solution = $dup.solution
                if ($keeper.status -eq 'incomplete' -or $keeper.status -eq 'title-only') { $keeper.status = 'complete' }
                $solutionsCopied++
            }

            $idx = $problemIdx[$dup.id]
            $problems[$idx].status = 'duplicate'
            $likelyDup++
            [Console]::Out.WriteLine("  LIKELY DUP: ID $($dup.id) '$($dup.title)' -> kept ID $($keeper.id) (graph=$graphScore, title=$titleJac, stmt=$stmtSim)")
        } elseif ($graphScore -ge 0.85 -and $titleJac -ge 0.5) {
            # FLAG for review
            $flagged++
            if ($flagged -le 20) {
                [Console]::Out.WriteLine("  FLAG: ID $($p1.id) vs ID $($p2.id) (graph=$graphScore, title=$titleJac) '$($p1.title)' vs '$($p2.title)'")
            }
        }
    }
}

# ============ ADDITIONAL: Statement-only dedup for problems without graph edges ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Running statement prefix scan for ungraphed problems...")

# Group non-duplicate problems by category for statement comparison
$byCategory = @{}
foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    $cat = $p.category
    if (-not $byCategory.ContainsKey($cat)) { $byCategory[$cat] = @() }
    $byCategory[$cat] += $p
}

$stmtDups = 0
foreach ($cat in $byCategory.Keys) {
    $catProbs = @($byCategory[$cat])
    if ($catProbs.Count -lt 2) { continue }

    # Build normalized statement prefixes
    $prefixes = @{}
    foreach ($p in $catProbs) {
        if (-not $p.statement -or $p.statement.Length -lt 30) { continue }
        $norm = $p.statement.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
        $norm = $norm.Trim()
        if ($norm.Length -gt 10) {
            $prefix = $norm.Substring(0, [math]::Min(100, $norm.Length))
            if (-not $prefixes.ContainsKey($prefix)) { $prefixes[$prefix] = @() }
            $prefixes[$prefix] += $p
        }
    }

    foreach ($prefix in $prefixes.Keys) {
        $matches = @($prefixes[$prefix] | Where-Object { $_.status -ne 'duplicate' })
        if ($matches.Count -gt 1) {
            $sorted = @($matches | Sort-Object { -(Get-SolutionQuality $_) }, { $_.id })
            $keeper = $sorted[0]
            for ($i = 1; $i -lt $sorted.Count; $i++) {
                $dup = $sorted[$i]
                $pairKey = "$([math]::Min($keeper.id, $dup.id))-$([math]::Max($keeper.id, $dup.id))"
                if ($pairs.ContainsKey($pairKey)) { continue }
                $pairs[$pairKey] = $true

                if ($dup.companies) {
                    foreach ($c in $dup.companies) {
                        if ($c -notin $keeper.companies) {
                            $keeper.companies = @($keeper.companies) + $c
                            $companiesMerged++
                        }
                    }
                }
                if ((-not $keeper.solution -or $keeper.solution.Length -lt 50) -and $dup.solution -and $dup.solution.Length -gt 50) {
                    $keeper.solution = $dup.solution
                    if ($keeper.status -eq 'incomplete' -or $keeper.status -eq 'title-only') { $keeper.status = 'complete' }
                    $solutionsCopied++
                }

                $idx = $problemIdx[$dup.id]
                $problems[$idx].status = 'duplicate'
                $stmtDups++
                [Console]::Out.WriteLine("  STMT DUP: ID $($dup.id) '$($dup.title)' -> kept ID $($keeper.id)")
            }
        }
    }
}

# ============ REPORT ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("DEDUP RESULTS:")
[Console]::Out.WriteLine("  Exact title duplicates: $exactTitleDups")
[Console]::Out.WriteLine("  Graph auto-merged: $autoMerged")
[Console]::Out.WriteLine("  Graph likely dups: $likelyDup")
[Console]::Out.WriteLine("  Statement prefix dups: $stmtDups")
[Console]::Out.WriteLine("  Flagged for review: $flagged")
[Console]::Out.WriteLine("  Companies merged: $companiesMerged")
[Console]::Out.WriteLine("  Solutions copied: $solutionsCopied")
[Console]::Out.WriteLine("  Total newly marked duplicate: $($exactTitleDups + $autoMerged + $likelyDup + $stmtDups)")
[Console]::Out.WriteLine("=========================================")

# Final status breakdown
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
