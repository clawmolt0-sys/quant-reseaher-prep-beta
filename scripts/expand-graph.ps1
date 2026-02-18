# Expand knowledge graph with new problems
# Adds edges for problems that don't have edges yet
# Uses keyword/tag/category matching to find similar problems

param(
    [int]$BatchStart = 0,
    [int]$BatchEnd = 99999,
    [switch]$DryRun = $false
)

$dataDir = "$PSScriptRoot\..\data"
$graphPath = "$dataDir\similarity-graph.json"
$problemsPath = "$dataDir\problems.json"

[Console]::Out.WriteLine("Loading data...")
$graph = Get-Content $graphPath -Raw | ConvertFrom-Json
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json

# Build lookup structures
$problemById = @{}
$problemsByCategory = @{}
$problemsByTag = @{}
$completeProblems = @()

foreach ($p in $problems) {
    $problemById[$p.id] = $p
    if ($p.status -eq 'complete') {
        $completeProblems += $p
        $cat = $p.category
        if (-not $problemsByCategory.ContainsKey($cat)) { $problemsByCategory[$cat] = @() }
        $problemsByCategory[$cat] += $p

        if ($p.tags) {
            foreach ($t in $p.tags) {
                if (-not $problemsByTag.ContainsKey($t)) { $problemsByTag[$t] = @() }
                $problemsByTag[$t] += $p
            }
        }
    }
}

[Console]::Out.WriteLine("Complete problems: $($completeProblems.Count)")
[Console]::Out.WriteLine("Categories: $($problemsByCategory.Count)")
[Console]::Out.WriteLine("Tags: $($problemsByTag.Count)")

# Get existing edge nodes
$existingNodes = @{}
foreach ($key in $graph.edges.PSObject.Properties.Name) {
    $existingNodes[[int]$key] = $true
}
[Console]::Out.WriteLine("Existing graph nodes: $($existingNodes.Count)")

# Find problems that need edges (complete but not in graph)
$needEdges = @()
foreach ($p in $completeProblems) {
    if (-not $existingNodes.ContainsKey($p.id)) {
        if ($p.id -ge $BatchStart -and $p.id -le $BatchEnd) {
            $needEdges += $p
        }
    }
}
[Console]::Out.WriteLine("Problems needing edges (in batch $BatchStart-$BatchEnd): $($needEdges.Count)")

if ($needEdges.Count -eq 0) {
    [Console]::Out.WriteLine("Nothing to do.")
    return
}

# ============ KEYWORD EXTRACTION ============
function Get-Keywords($text) {
    if (-not $text) { return @() }
    $lower = $text.ToLower()
    # Remove LaTeX
    $lower = $lower -replace '\$[^$]+\$', ''
    $lower = $lower -replace '\\[a-zA-Z]+', ''
    # Split into words
    $words = $lower -split '[^a-zA-Z0-9]+' | Where-Object { $_.Length -gt 3 }
    # Remove common stop words
    $stopWords = @('that','this','with','from','have','been','will','would','could','should','which','their','there','they','about','after','before','being','between','both','during','each','than','then','these','those','through','under','very','what','when','where','while','into','most','much','must','only','other','over','same','some','such','also','just','like','make','many','more','need','find','given','know','take','want','does','using','used','consider','following','problem','question','answer','solution','solve','determine','calculate','compute','show','prove','explain','suppose','assume','let')
    $filtered = $words | Where-Object { $_ -notin $stopWords } | Sort-Object -Unique
    return $filtered
}

# ============ SIMILARITY SCORING ============
function Get-Similarity($p1, $p2) {
    $score = 0
    $reasons = @()
    $edgeType = "same_concept"
    $concepts = @()

    # Same category bonus
    if ($p1.category -eq $p2.category) {
        $score += 0.3
        $reasons += "same category ($($p1.category))"
    }

    # Tag overlap
    $tags1 = @()
    $tags2 = @()
    if ($p1.tags) { $tags1 = @($p1.tags) }
    if ($p2.tags) { $tags2 = @($p2.tags) }

    if ($tags1.Count -gt 0 -and $tags2.Count -gt 0) {
        $shared = @($tags1 | Where-Object { $_ -in $tags2 })
        if ($shared.Count -gt 0) {
            $overlap = $shared.Count / [math]::Max(1, [math]::Min($tags1.Count, $tags2.Count))
            $score += $overlap * 0.4
            $reasons += "shared tags: $($shared -join ', ')"
            $concepts += $shared
        }
    }

    # Keyword overlap from statements
    $kw1 = Get-Keywords $p1.statement
    $kw2 = Get-Keywords $p2.statement

    if ($kw1.Count -gt 0 -and $kw2.Count -gt 0) {
        $sharedKw = @($kw1 | Where-Object { $_ -in $kw2 })
        if ($sharedKw.Count -gt 0) {
            $kwOverlap = $sharedKw.Count / [math]::Max(1, [math]::Min($kw1.Count, $kw2.Count))
            $score += $kwOverlap * 0.3
        }
    }

    # Difficulty match bonus
    if ($p1.difficulty -eq $p2.difficulty) {
        $score += 0.05
    }

    # Company overlap
    if ($p1.companies -and $p2.companies) {
        $sharedComp = @($p1.companies | Where-Object { $_ -in $p2.companies })
        if ($sharedComp.Count -gt 0) {
            $score += 0.05
            $reasons += "asked at same company"
        }
    }

    # Determine edge type
    if ($p1.category -ne $p2.category) {
        if ($score -gt 0.3) {
            $edgeType = "application"
            $reasons = @("Cross-domain application: $($p1.category) concepts applied in $($p2.category) context") + $reasons
        }
    } elseif ($tags1.Count -gt 0 -and $tags2.Count -gt 0) {
        $shared = @($tags1 | Where-Object { $_ -in $tags2 })
        if ($shared.Count -ge 2) {
            $edgeType = "same_technique"
        } elseif ($shared.Count -eq 1) {
            $edgeType = "same_concept"
        } else {
            $edgeType = "variant"
        }
    }

    # Build reason string
    $reasonStr = if ($reasons.Count -gt 0) {
        "Both involve " + ($reasons | Select-Object -First 2) -join " and "
    } else {
        "Related problems in $($p1.category)"
    }

    # Cap score
    $score = [math]::Min(0.99, [math]::Max(0.1, $score))

    return @{
        score = [math]::Round($score, 2)
        reason = $reasonStr
        edgeType = $edgeType
        concepts = $concepts
    }
}

# ============ BUILD EDGES FOR NEW PROBLEMS ============
$newEdgeCount = 0
$processedCount = 0

foreach ($p in $needEdges) {
    $processedCount++
    if ($processedCount % 50 -eq 0) {
        [Console]::Out.WriteLine("  Processing $processedCount / $($needEdges.Count)...")
    }

    # Find candidates: same category + tag overlap
    $candidates = @()

    # Same category problems
    $sameCat = $problemsByCategory[$p.category]
    if ($sameCat) {
        foreach ($c in $sameCat) {
            if ($c.id -ne $p.id -and $c.status -eq 'complete') {
                $candidates += $c
            }
        }
    }

    # Also add tag-matched problems from other categories (for cross-domain edges)
    if ($p.tags) {
        foreach ($t in $p.tags) {
            $tagProbs = $problemsByTag[$t]
            if ($tagProbs) {
                foreach ($c in $tagProbs) {
                    if ($c.id -ne $p.id -and $c.category -ne $p.category -and $c.status -eq 'complete') {
                        $candidates += $c
                    }
                }
            }
        }
    }

    # Deduplicate candidates
    $seen = @{}
    $uniqueCandidates = @()
    foreach ($c in $candidates) {
        if (-not $seen.ContainsKey($c.id)) {
            $seen[$c.id] = $true
            $uniqueCandidates += $c
        }
    }

    # Score all candidates
    $scored = @()
    foreach ($c in $uniqueCandidates) {
        $sim = Get-Similarity $p $c
        if ($sim.score -ge 0.3) {
            $scored += @{
                id = $c.id
                w = $sim.score
                r = $sim.reason
                type = $sim.edgeType
                concepts = $sim.concepts
            }
        }
    }

    # Sort by score descending, take top 10
    $sorted = $scored | Sort-Object { $_.w } -Descending | Select-Object -First 10

    if ($sorted.Count -gt 0) {
        # Convert to proper objects
        $edges = @()
        foreach ($s in $sorted) {
            $edge = [PSCustomObject]@{
                id = $s.id
                w = $s.w
                r = $s.r
                type = $s.type
                concepts = @($s.concepts | Select-Object -Unique)
            }
            $edges += $edge
            $newEdgeCount++
        }

        # Add to graph using PSObject.Properties to avoid Add-Member issues
        $propName = "$($p.id)"
        $existingProp = $graph.edges.PSObject.Properties[$propName]
        if ($existingProp) {
            $existingProp.Value = $edges
        } else {
            $graph.edges.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new($propName, $edges))
        }

        # Also add reverse edges (bidirectional)
        foreach ($e in $edges) {
            $targetKey = "$($e.id)"
            $existingEdges = @()
            $targetProp = $graph.edges.PSObject.Properties[$targetKey]
            if ($targetProp) {
                $existingEdges = @($targetProp.Value)
            }
            # Check if reverse edge already exists
            $hasReverse = $false
            foreach ($ex in $existingEdges) {
                if ($ex.id -eq $p.id) { $hasReverse = $true; break }
            }
            if (-not $hasReverse) {
                $reverseEdge = [PSCustomObject]@{
                    id = $p.id
                    w = $e.w
                    r = $e.r
                    type = $e.type
                    concepts = $e.concepts
                }
                $existingEdges += $reverseEdge
                if ($targetProp) {
                    $targetProp.Value = $existingEdges
                } else {
                    $graph.edges.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new($targetKey, $existingEdges))
                }
                $newEdgeCount++
            }
        }
    }

    # Update concept lists
    if ($p.tags) {
        foreach ($t in $p.tags) {
            $conceptKey = $t -replace '\s+', '-'
            $conceptKey = $conceptKey.ToLower()
            if ($graph.concepts.PSObject.Properties.Name -contains $conceptKey) {
                $concept = $graph.concepts.$conceptKey
                $existingProbs = @($concept.problems)
                if ($p.id -notin $existingProbs) {
                    $concept.problems = @($existingProbs + $p.id)
                }
            }
        }
    }
}

# Update meta
$totalEdges = 0
foreach ($key in $graph.edges.PSObject.Properties.Name) {
    $totalEdges += @($graph.edges.$key).Count
}
$graph._meta.problemCount = $graph.edges.PSObject.Properties.Name.Count
$graph._meta.edgeCount = $totalEdges

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("GRAPH EXPANSION RESULTS:")
[Console]::Out.WriteLine("  New edges added: $newEdgeCount")
[Console]::Out.WriteLine("  Total nodes: $($graph._meta.problemCount)")
[Console]::Out.WriteLine("  Total edges: $($graph._meta.edgeCount)")
[Console]::Out.WriteLine("=========================================")

if ($DryRun) {
    [Console]::Out.WriteLine("")
    [Console]::Out.WriteLine("[DRY RUN] No files modified.")
    return
}

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Saving graph...")
$graph | ConvertTo-Json -Depth 10 -Compress | Set-Content $graphPath -Encoding UTF8
$size = [math]::Round((Get-Item $graphPath).Length / 1KB, 1)
[Console]::Out.WriteLine("Done. File size: ${size} KB")
