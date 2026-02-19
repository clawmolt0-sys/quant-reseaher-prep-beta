# Second-pass dedup: find duplicates among newly-added PDF problems
# These are problems that were added from different PDFs but are actually the same question

$problemsPath = "$PSScriptRoot\..\data\problems.json"
[Console]::Out.WriteLine("Loading problems.json...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
[Console]::Out.WriteLine("  Total: $($problems.Count)")

# Build lookup
$problemById = @{}
$problemIdx = @{}
for ($i = 0; $i -lt $problems.Count; $i++) {
    $problemById[$problems[$i].id] = $problems[$i]
    $problemIdx[$problems[$i].id] = $i
}

function Get-TitleJaccard($t1, $t2) {
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

function Get-StmtMatch($s1, $s2) {
    if (-not $s1 -or -not $s2) { return 0 }
    $n1 = $s1.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
    $n2 = $s2.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
    $n1 = $n1.Trim(); $n2 = $n2.Trim()
    if ($n1.Length -lt 20 -or $n2.Length -lt 20) { return 0 }
    $len = [math]::Min(200, [math]::Min($n1.Length, $n2.Length))
    $sub1 = $n1.Substring(0, $len); $sub2 = $n2.Substring(0, $len)
    $matches = 0
    for ($i = 0; $i -lt $len; $i++) { if ($sub1[$i] -eq $sub2[$i]) { $matches++ } }
    return [math]::Round($matches / $len, 3)
}

function Get-SolutionQuality($p) {
    if (-not $p.solution -or $p.solution.Length -lt 50) { return 0 }
    $score = [math]::Min($p.solution.Length / 500.0, 1.0)
    if ($p.solution -match '\$') { $score += 0.1 }
    if ($p.solution -match '##|Step|\\begin') { $score += 0.1 }
    return [math]::Round($score, 2)
}

# Group all non-duplicate problems by category
$byCategory = @{}
foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    $cat = $p.category
    if (-not $byCategory.ContainsKey($cat)) { $byCategory[$cat] = @() }
    $byCategory[$cat] += $p
}

$totalDups = 0
$totalMerged = 0
$pairs = @{}

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Scanning for within-category duplicates...")

foreach ($cat in $byCategory.Keys) {
    $catProbs = @($byCategory[$cat])
    if ($catProbs.Count -lt 2) { continue }

    # Build title word sets
    $titleData = @()
    foreach ($p in $catProbs) {
        $words = @($p.title.ToLower() -split '[^a-zA-Z0-9]+' | Where-Object { $_.Length -gt 2 })
        $titleData += @{ problem = $p; words = $words }
    }

    # Compare all pairs (O(n^2) but within each category)
    for ($i = 0; $i -lt $titleData.Count; $i++) {
        $p1 = $titleData[$i].problem
        if ($p1.status -eq 'duplicate') { continue }

        for ($j = $i + 1; $j -lt $titleData.Count; $j++) {
            $p2 = $titleData[$j].problem
            if ($p2.status -eq 'duplicate') { continue }

            $pairKey = "$([math]::Min($p1.id, $p2.id))-$([math]::Max($p1.id, $p2.id))"
            if ($pairs.ContainsKey($pairKey)) { continue }

            # Quick title Jaccard check
            $titleJac = Get-TitleJaccard $p1.title $p2.title
            if ($titleJac -lt 0.5) { continue }

            # Statement similarity check
            $stmtSim = Get-StmtMatch $p1.statement $p2.statement

            # Decision
            $isDup = $false
            if ($titleJac -ge 0.9 -and $stmtSim -ge 0.7) { $isDup = $true }
            elseif ($titleJac -ge 0.8 -and $stmtSim -ge 0.8) { $isDup = $true }
            elseif ($titleJac -ge 0.7 -and $stmtSim -ge 0.9) { $isDup = $true }
            elseif ($titleJac -eq 1.0) { $isDup = $true }

            if ($isDup) {
                $pairs[$pairKey] = $true
                $q1 = Get-SolutionQuality $p1
                $q2 = Get-SolutionQuality $p2
                # Prefer complete over incomplete, then better solution, then lower ID
                $keeper = $null; $dup = $null
                if ($p1.status -eq 'complete' -and $p2.status -ne 'complete') { $keeper = $p1; $dup = $p2 }
                elseif ($p2.status -eq 'complete' -and $p1.status -ne 'complete') { $keeper = $p2; $dup = $p1 }
                elseif ($q1 -ge $q2) { $keeper = $p1; $dup = $p2 }
                else { $keeper = $p2; $dup = $p1 }

                # Merge companies
                if ($dup.companies) {
                    foreach ($c in $dup.companies) {
                        if ($c -notin @($keeper.companies)) {
                            $keeper.companies = @($keeper.companies) + $c
                            $totalMerged++
                        }
                    }
                }
                # Copy solution if keeper lacks one
                if ((-not $keeper.solution -or $keeper.solution.Length -lt 50) -and $dup.solution -and $dup.solution.Length -gt 50) {
                    $keeper.solution = $dup.solution
                    if ($keeper.status -ne 'complete') { $keeper.status = 'complete' }
                }

                $idx = $problemIdx[$dup.id]
                $problems[$idx].status = 'duplicate'
                $totalDups++

                if ($totalDups -le 30 -or $totalDups % 50 -eq 0) {
                    [Console]::Out.WriteLine("  DUP: ID $($dup.id) '$($dup.title.Substring(0, [math]::Min(50, $dup.title.Length)))' -> kept ID $($keeper.id) (title=$titleJac, stmt=$stmtSim)")
                }
            }
        }
    }
}

# ============ Also check exact title fingerprints across categories ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Checking cross-category title fingerprints...")

$allFps = @{}
$crossCatDups = 0
foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    $fp = ($p.title.ToLower() -replace '[^a-z0-9]', '').Trim()
    if ($fp.Length -le 10) { continue }

    if ($allFps.ContainsKey($fp)) {
        $keeper = $allFps[$fp]
        $pairKey = "$([math]::Min($keeper.id, $p.id))-$([math]::Max($keeper.id, $p.id))"
        if ($pairs.ContainsKey($pairKey)) { continue }
        $pairs[$pairKey] = $true

        # Check stmt too to avoid false positives
        $stmtSim = Get-StmtMatch $p.statement $keeper.statement
        if ($stmtSim -ge 0.3 -or $p.title.Length -gt 30) {
            $q1 = Get-SolutionQuality $keeper
            $q2 = Get-SolutionQuality $p
            $dup = if ($q1 -ge $q2) { $p } else { $keeper }
            $keep = if ($q1 -ge $q2) { $keeper } else { $p }

            if ($dup.companies) {
                foreach ($c in $dup.companies) {
                    if ($c -notin @($keep.companies)) {
                        $keep.companies = @($keep.companies) + $c
                        $totalMerged++
                    }
                }
            }

            $idx = $problemIdx[$dup.id]
            $problems[$idx].status = 'duplicate'
            $crossCatDups++
            $totalDups++

            if ($crossCatDups -le 20) {
                [Console]::Out.WriteLine("  CROSS-CAT DUP: ID $($dup.id) -> kept ID $($keep.id) '$($keep.title.Substring(0, [math]::Min(50, $keep.title.Length)))'")
            }

            # Update the fingerprint to point to the keeper
            $allFps[$fp] = $keep
        }
    } else {
        $allFps[$fp] = $p
    }
}

# ============ REPORT ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("SECOND-PASS DEDUP RESULTS:")
[Console]::Out.WriteLine("  Within-category dups: $($totalDups - $crossCatDups)")
[Console]::Out.WriteLine("  Cross-category dups: $crossCatDups")
[Console]::Out.WriteLine("  Total new duplicates: $totalDups")
[Console]::Out.WriteLine("  Companies merged: $totalMerged")
[Console]::Out.WriteLine("=========================================")

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
