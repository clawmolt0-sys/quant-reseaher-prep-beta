# Build fingerprints for every problem and expand the knowledge graph
# A fingerprint = a normalized, comparable representation of each problem
# Used for: dedup, similarity search, related problems, quality checks
#
# Fingerprint components:
#   1. title_fp: normalized title (lowercase, no punctuation, sorted words)
#   2. stmt_fp: first 100 chars of normalized statement
#   3. keywords: top 15 content keywords (excluding stopwords)
#   4. concept_signature: category + difficulty + type hash
#
# Then: build similarity edges between ALL problems (not just complete ones)
# and use them for aggressive dedup

$dataDir = "$PSScriptRoot\..\data"
$problemsPath = "$dataDir\problems.json"
$graphPath = "$dataDir\similarity-graph.json"

[Console]::Out.WriteLine("Loading data...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
$graph = Get-Content $graphPath -Raw | ConvertFrom-Json
[Console]::Out.WriteLine("  Problems: $($problems.Count)")

# Stopwords
$stopWords = @('the','and','for','that','this','with','from','have','been','will','would','could','should','which','their','there','they','about','after','before','being','between','both','during','each','than','then','these','those','through','under','very','what','when','where','while','into','most','much','must','only','other','over','same','some','such','also','just','like','make','many','more','need','find','given','know','take','want','does','using','used','consider','following','problem','question','answer','solution','solve','determine','calculate','compute','show','prove','explain','suppose','assume','let','define','note','hint','example','task','context','asked','round','interview','write','implement','return','input','output','function','class','method','are','was','were','has','had','its','you','your','can','not','how','all','one','two','three','four','five','first','second','new','way','may','part','get','got','say','set','try','too','use','her','him','his','she','see','now','old','big','come','made','after','think','every','give','well','our','back')

function Get-Keywords($text) {
    if (-not $text) { return @() }
    $lower = $text.ToLower()
    $lower = $lower -replace '\$[^$]+\$', ' '
    $lower = $lower -replace '\\[a-zA-Z]+', ' '
    $lower = $lower -replace '[^a-zA-Z0-9\s]', ' '
    $words = @($lower -split '\s+' | Where-Object { $_.Length -gt 3 -and $_ -notin $stopWords })
    # Count frequency
    $freq = @{}
    foreach ($w in $words) { if ($freq.ContainsKey($w)) { $freq[$w]++ } else { $freq[$w] = 1 } }
    # Return top 15 by frequency
    $sorted = @($freq.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15 | ForEach-Object { $_.Key })
    return $sorted
}

function Get-TitleFingerprint($title) {
    if (-not $title) { return '' }
    $words = @($title.ToLower() -replace '[^a-zA-Z0-9\s]', '' -split '\s+' | Where-Object { $_.Length -gt 2 -and $_ -notin $stopWords } | Sort-Object)
    return ($words -join ' ')
}

function Get-StmtFingerprint($stmt) {
    if (-not $stmt -or $stmt.Length -lt 20) { return '' }
    $norm = $stmt.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
    $norm = $norm.Trim()
    if ($norm.Length -lt 15) { return '' }
    return $norm.Substring(0, [math]::Min(100, $norm.Length))
}

# ============ PHASE 1: BUILD FINGERPRINTS ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Building fingerprints...")

$fingerprints = @()
$fpById = @{}

foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }

    $titleFp = Get-TitleFingerprint $p.title
    $stmtFp = Get-StmtFingerprint $p.statement
    $keywords = Get-Keywords "$($p.title) $($p.statement)"

    $fp = @{
        id = $p.id
        title_fp = $titleFp
        stmt_fp = $stmtFp
        keywords = $keywords
        category = $p.category
        difficulty = $p.difficulty
        type = $p.type
        wordSet = @{}
    }
    foreach ($w in ($titleFp -split '\s+')) { if ($w.Length -gt 0) { $fp.wordSet[$w] = $true } }

    $fingerprints += $fp
    $fpById[$p.id] = $fp
}

[Console]::Out.WriteLine("  Built $($fingerprints.Count) fingerprints")

# ============ PHASE 2: COMPUTE SIMILARITIES & DEDUP ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Computing pairwise similarities for dedup...")

# Group by category for faster comparison
$byCategory = @{}
foreach ($fp in $fingerprints) {
    $cat = $fp.category
    if (-not $byCategory.ContainsKey($cat)) { $byCategory[$cat] = @() }
    $byCategory[$cat] += $fp
}

$problemByIdLookup = @{}
foreach ($p in $problems) { $problemByIdLookup[$p.id] = $p }

$newDups = 0
$pairs = @{}
$newEdges = @{}  # For graph expansion

function Get-Similarity($fp1, $fp2) {
    # Title Jaccard
    $titleJac = 0
    if ($fp1.wordSet.Count -gt 0 -and $fp2.wordSet.Count -gt 0) {
        $inter = 0
        foreach ($w in $fp1.wordSet.Keys) { if ($fp2.wordSet.ContainsKey($w)) { $inter++ } }
        $union = $fp1.wordSet.Count + $fp2.wordSet.Count - $inter
        $titleJac = if ($union -gt 0) { $inter / $union } else { 0 }
    }

    # Keyword overlap
    $kwOverlap = 0
    if ($fp1.keywords.Count -gt 0 -and $fp2.keywords.Count -gt 0) {
        $kw1 = @{}; foreach ($k in $fp1.keywords) { $kw1[$k] = $true }
        $shared = @($fp2.keywords | Where-Object { $kw1.ContainsKey($_) })
        $kwOverlap = $shared.Count / [math]::Max(1, [math]::Min($fp1.keywords.Count, $fp2.keywords.Count))
    }

    # Statement prefix similarity
    $stmtSim = 0
    if ($fp1.stmt_fp.Length -gt 20 -and $fp2.stmt_fp.Length -gt 20) {
        $len = [math]::Min($fp1.stmt_fp.Length, $fp2.stmt_fp.Length)
        $matches = 0
        for ($i = 0; $i -lt $len; $i++) { if ($fp1.stmt_fp[$i] -eq $fp2.stmt_fp[$i]) { $matches++ } }
        $stmtSim = $matches / $len
    }

    # Category/type bonus
    $catBonus = 0
    if ($fp1.category -eq $fp2.category) { $catBonus += 0.1 }
    if ($fp1.type -eq $fp2.type) { $catBonus += 0.05 }

    # Combined score
    $score = ($titleJac * 0.35) + ($kwOverlap * 0.30) + ($stmtSim * 0.25) + ($catBonus * 0.10)
    return @{ score = [math]::Round($score, 3); titleJac = [math]::Round($titleJac, 3); kwOverlap = [math]::Round($kwOverlap, 3); stmtSim = [math]::Round($stmtSim, 3) }
}

# Compare within each category
foreach ($cat in $byCategory.Keys) {
    $catFps = @($byCategory[$cat])
    if ($catFps.Count -lt 2) { continue }

    for ($i = 0; $i -lt $catFps.Count; $i++) {
        $fp1 = $catFps[$i]
        $p1 = $problemByIdLookup[$fp1.id]
        if ($p1.status -eq 'duplicate') { continue }

        for ($j = $i + 1; $j -lt $catFps.Count; $j++) {
            $fp2 = $catFps[$j]
            $p2 = $problemByIdLookup[$fp2.id]
            if ($p2.status -eq 'duplicate') { continue }

            $pairKey = "$([math]::Min($fp1.id, $fp2.id))-$([math]::Max($fp1.id, $fp2.id))"
            if ($pairs.ContainsKey($pairKey)) { continue }

            # Quick filter
            if ($fp1.wordSet.Count -eq 0 -or $fp2.wordSet.Count -eq 0) { continue }
            $quickInter = 0
            foreach ($w in $fp1.wordSet.Keys) { if ($fp2.wordSet.ContainsKey($w)) { $quickInter++; if ($quickInter -ge 2) { break } } }
            if ($quickInter -lt 2) { continue }

            $sim = Get-Similarity $fp1 $fp2
            $pairs[$pairKey] = $true

            # Store high-similarity edges for graph
            if ($sim.score -ge 0.5) {
                $edgeData = @{ id = $fp2.id; w = $sim.score; t = 'similar' }
                if (-not $newEdges.ContainsKey($fp1.id)) { $newEdges[$fp1.id] = @() }
                $newEdges[$fp1.id] += $edgeData
            }

            # Dedup decision
            $isDup = $false
            if ($sim.score -ge 0.75 -and $sim.titleJac -ge 0.7) { $isDup = $true }
            if ($sim.titleJac -ge 0.9 -and $sim.stmtSim -ge 0.5) { $isDup = $true }
            if ($sim.stmtSim -ge 0.85) { $isDup = $true }
            if ($sim.titleJac -eq 1.0 -and $sim.kwOverlap -ge 0.5) { $isDup = $true }

            if ($isDup) {
                # Pick keeper (prefer complete, then longer solution, then lower ID)
                $q1 = if ($p1.status -eq 'complete') { 1000 } else { 0 }
                $q1 += if ($p1.solution) { $p1.solution.Length } else { 0 }
                $q2 = if ($p2.status -eq 'complete') { 1000 } else { 0 }
                $q2 += if ($p2.solution) { $p2.solution.Length } else { 0 }

                $keeper = if ($q1 -ge $q2) { $p1 } else { $p2 }
                $dup = if ($q1 -ge $q2) { $p2 } else { $p1 }

                # Merge
                if ($dup.companies) {
                    foreach ($c in $dup.companies) {
                        if ($c -notin @($keeper.companies)) { $keeper.companies = @($keeper.companies) + $c }
                    }
                }
                if ((-not $keeper.solution -or $keeper.solution.Length -lt 50) -and $dup.solution -and $dup.solution.Length -gt 50) {
                    $keeper.solution = $dup.solution
                    if ($keeper.status -ne 'complete') { $keeper.status = 'complete' }
                }
                if ($dup.tags) { foreach ($t in $dup.tags) { if ($t -and $t -notin @($keeper.tags)) { $keeper.tags = @($keeper.tags) + $t } } }

                $idx = [Array]::IndexOf($problems, $dup)
                if ($idx -ge 0) { $problems[$idx].status = 'duplicate' }
                $newDups++

                if ($newDups -le 30 -or $newDups % 100 -eq 0) {
                    [Console]::Out.WriteLine("  DUP #${newDups}: ID $($dup.id) -> ID $($keeper.id) (score=$($sim.score), title=$($sim.titleJac), kw=$($sim.kwOverlap), stmt=$($sim.stmtSim))")
                }
            }
        }
    }
}

[Console]::Out.WriteLine("  New duplicates from fingerprint comparison: $newDups")

# ============ PHASE 3: EXPAND GRAPH ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Expanding knowledge graph with new edges...")

$existingNodeCount = $graph.edges.PSObject.Properties.Name.Count
$newNodeCount = 0
$newEdgeCount = 0

foreach ($nodeId in $newEdges.Keys) {
    $edges = @($newEdges[$nodeId])
    $propName = "$nodeId"

    $existingProp = $graph.edges.PSObject.Properties[$propName]
    if ($existingProp) {
        # Merge new edges with existing
        $existing = @($existingProp.Value)
        $existingIds = @{}
        foreach ($e in $existing) { $existingIds[$e.id] = $true }
        foreach ($e in $edges) {
            if (-not $existingIds.ContainsKey($e.id)) {
                $existing += $e
                $newEdgeCount++
            }
        }
        $existingProp.Value = $existing
    } else {
        # New node
        try {
            $graph.edges.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new($propName, $edges))
            $newNodeCount++
            $newEdgeCount += $edges.Count
        } catch {
            # Skip if can't add
        }
    }
}

[Console]::Out.WriteLine("  New graph nodes: $newNodeCount")
[Console]::Out.WriteLine("  New graph edges: $newEdgeCount")
[Console]::Out.WriteLine("  Total graph nodes: $($graph.edges.PSObject.Properties.Name.Count)")

# ============ REPORT ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("FINGERPRINT + GRAPH DEDUP RESULTS:")
[Console]::Out.WriteLine("  New duplicates found: $newDups")
[Console]::Out.WriteLine("  New graph edges: $newEdgeCount")
[Console]::Out.WriteLine("=========================================")

$statuses = $problems | Group-Object status | Sort-Object Count -Descending
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Status breakdown:")
foreach ($s in $statuses) { [Console]::Out.WriteLine("  $($s.Name): $($s.Count)") }

# Save both files
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Saving...")
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8
$pSize = [math]::Round((Get-Item $problemsPath).Length / 1KB)
[Console]::Out.WriteLine("  problems.json: ${pSize} KB")

$graph | ConvertTo-Json -Depth 5 -Compress | Set-Content $graphPath -Encoding UTF8
$gSize = [math]::Round((Get-Item $graphPath).Length / 1KB)
[Console]::Out.WriteLine("  similarity-graph.json: ${gSize} KB")
[Console]::Out.WriteLine("Done.")
