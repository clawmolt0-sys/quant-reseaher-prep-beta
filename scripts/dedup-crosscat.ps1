# Cross-category dedup - catch duplicates where the same problem is in different categories
# Uses title fingerprint + statement prefix matching across ALL categories

$problemsPath = "$PSScriptRoot\..\data\problems.json"
[Console]::Out.WriteLine("Loading problems...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
[Console]::Out.WriteLine("  Total: $($problems.Count)")

$stopWords = @('the','and','for','that','this','with','from','have','been','will','would','could','should','which','their','there','they','about','after','before','being','between','both','during','each','than','then','these','those','through','under','very','what','when','where','while','into','most','much','must','only','other','over','same','some','such','also','just','like','make','many','more','need','find','given','know','take','want','does','using','used','consider','following','problem','question','answer','solution','solve','determine','calculate','compute','show','prove','explain','suppose','assume','let','define','note','hint','example','task','context','asked','round','interview','write','implement','return','input','output','function','class','method','are','was','were','has','had','its','you','your','can','not','how','all','one','two','three','four','five','first','second','new','way','may','part','get','got','say','set','try','too','use','her','him','his','she','see','now','old','big','come','made','after','think','every','give','well','our','back')

function Get-TitleFP($title) {
    if (-not $title) { return '' }
    $words = @($title.ToLower() -replace '[^a-zA-Z0-9\s]', '' -split '\s+' | Where-Object { $_.Length -gt 2 -and $_ -notin $stopWords } | Sort-Object)
    return ($words -join ' ')
}

function Get-StmtNorm($stmt) {
    if (-not $stmt -or $stmt.Length -lt 20) { return '' }
    $norm = $stmt.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
    $norm = $norm.Trim()
    if ($norm.Length -lt 15) { return '' }
    return $norm.Substring(0, [math]::Min(200, $norm.Length))
}

# Build lookup by title fingerprint
$byTitleFP = @{}
$active = @($problems | Where-Object { $_.status -ne 'duplicate' })
[Console]::Out.WriteLine("  Active problems: $($active.Count)")

foreach ($p in $active) {
    $tfp = Get-TitleFP $p.title
    if ($tfp.Length -lt 3) { continue }
    if (-not $byTitleFP.ContainsKey($tfp)) { $byTitleFP[$tfp] = @() }
    $byTitleFP[$tfp] += $p
}

# Find exact title fingerprint duplicates (cross-category)
$newDups = 0
$mergedCompanies = 0

foreach ($tfp in $byTitleFP.Keys) {
    $group = @($byTitleFP[$tfp])
    if ($group.Count -lt 2) { continue }

    # Check if these are cross-category
    $cats = @($group | ForEach-Object { $_.category } | Select-Object -Unique)
    if ($cats.Count -lt 2) { continue }  # Same category - already handled by build-fingerprints

    # Also verify statement similarity for cross-cat matches
    for ($i = 0; $i -lt $group.Count; $i++) {
        $p1 = $group[$i]
        if ($p1.status -eq 'duplicate') { continue }
        $s1 = Get-StmtNorm $p1.statement

        for ($j = $i + 1; $j -lt $group.Count; $j++) {
            $p2 = $group[$j]
            if ($p2.status -eq 'duplicate') { continue }
            $s2 = Get-StmtNorm $p2.statement

            # For cross-category: require either stmt similarity OR both have no stmt
            $stmtMatch = $false
            if ($s1.Length -gt 20 -and $s2.Length -gt 20) {
                $len = [math]::Min($s1.Length, $s2.Length)
                $matches = 0
                for ($k = 0; $k -lt $len; $k++) { if ($s1[$k] -eq $s2[$k]) { $matches++ } }
                $stmtSim = $matches / $len
                if ($stmtSim -ge 0.5) { $stmtMatch = $true }
            } elseif ($s1.Length -lt 20 -and $s2.Length -lt 20) {
                # Both have short/no statements but identical title fingerprint
                $stmtMatch = $true
            }

            if (-not $stmtMatch) { continue }

            # Pick keeper: prefer complete > longer solution > lower ID
            $q1 = 0; $q2 = 0
            if ($p1.status -eq 'complete') { $q1 += 1000 }
            if ($p1.solution) { $q1 += $p1.solution.Length }
            if ($p2.status -eq 'complete') { $q2 += 1000 }
            if ($p2.solution) { $q2 += $p2.solution.Length }

            $keeper = if ($q1 -ge $q2) { $p1 } else { $p2 }
            $dup = if ($q1 -ge $q2) { $p2 } else { $p1 }

            # Merge companies
            if ($dup.companies) {
                foreach ($c in $dup.companies) {
                    if ($c -notin @($keeper.companies)) {
                        $keeper.companies = @($keeper.companies) + $c
                        $mergedCompanies++
                    }
                }
            }

            # Merge solution
            if ((-not $keeper.solution -or $keeper.solution.Length -lt 50) -and $dup.solution -and $dup.solution.Length -gt 50) {
                $keeper.solution = $dup.solution
                if ($keeper.status -ne 'complete') { $keeper.status = 'complete' }
            }

            # Merge tags
            if ($dup.tags) {
                foreach ($t in $dup.tags) {
                    if ($t -and $t -notin @($keeper.tags)) { $keeper.tags = @($keeper.tags) + $t }
                }
            }

            # Mark dup
            $dup.status = 'duplicate'
            $newDups++

            if ($newDups -le 50) {
                [Console]::Out.WriteLine("  XCAT DUP #${newDups}: ID $($dup.id) [$($dup.category)] -> ID $($keeper.id) [$($keeper.category)] | '$tfp'")
            }
        }
    }
}

# Also do statement-prefix cross-cat scan
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Cross-category statement prefix scan...")

$byStmtPrefix = @{}
$active2 = @($problems | Where-Object { $_.status -ne 'duplicate' })
foreach ($p in $active2) {
    $sfp = Get-StmtNorm $p.statement
    if ($sfp.Length -lt 40) { continue }
    $key = $sfp.Substring(0, [math]::Min(80, $sfp.Length))
    if (-not $byStmtPrefix.ContainsKey($key)) { $byStmtPrefix[$key] = @() }
    $byStmtPrefix[$key] += $p
}

foreach ($key in $byStmtPrefix.Keys) {
    $group = @($byStmtPrefix[$key])
    if ($group.Count -lt 2) { continue }

    for ($i = 0; $i -lt $group.Count; $i++) {
        $p1 = $group[$i]
        if ($p1.status -eq 'duplicate') { continue }

        for ($j = $i + 1; $j -lt $group.Count; $j++) {
            $p2 = $group[$j]
            if ($p2.status -eq 'duplicate') { continue }
            if ($p1.category -eq $p2.category) { continue }  # Same cat already handled

            $q1 = 0; $q2 = 0
            if ($p1.status -eq 'complete') { $q1 += 1000 }
            if ($p1.solution) { $q1 += $p1.solution.Length }
            if ($p2.status -eq 'complete') { $q2 += 1000 }
            if ($p2.solution) { $q2 += $p2.solution.Length }

            $keeper = if ($q1 -ge $q2) { $p1 } else { $p2 }
            $dup = if ($q1 -ge $q2) { $p2 } else { $p1 }

            if ($dup.companies) {
                foreach ($c in $dup.companies) {
                    if ($c -notin @($keeper.companies)) {
                        $keeper.companies = @($keeper.companies) + $c
                        $mergedCompanies++
                    }
                }
            }
            if ((-not $keeper.solution -or $keeper.solution.Length -lt 50) -and $dup.solution -and $dup.solution.Length -gt 50) {
                $keeper.solution = $dup.solution
                if ($keeper.status -ne 'complete') { $keeper.status = 'complete' }
            }
            if ($dup.tags) { foreach ($t in $dup.tags) { if ($t -and $t -notin @($keeper.tags)) { $keeper.tags = @($keeper.tags) + $t } } }

            $dup.status = 'duplicate'
            $newDups++

            if ($newDups -le 50) {
                $titleShort = if ($dup.title.Length -gt 40) { $dup.title.Substring(0, 37) + '...' } else { $dup.title }
                [Console]::Out.WriteLine("  XCAT STMT #${newDups}: ID $($dup.id) [$($dup.category)] -> ID $($keeper.id) [$($keeper.category)] | $titleShort")
            }
        }
    }
}

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("CROSS-CATEGORY DEDUP RESULTS:")
[Console]::Out.WriteLine("  New duplicates: $newDups")
[Console]::Out.WriteLine("  Company tags merged: $mergedCompanies")
[Console]::Out.WriteLine("=========================================")

$statuses = $problems | Group-Object status | Sort-Object Count -Descending
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Status breakdown:")
foreach ($s in $statuses) { [Console]::Out.WriteLine("  $($s.Name): $($s.Count)") }

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Saving...")
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8
$size = [math]::Round((Get-Item $problemsPath).Length / 1KB)
[Console]::Out.WriteLine("  problems.json: ${size} KB")
[Console]::Out.WriteLine("Done.")
