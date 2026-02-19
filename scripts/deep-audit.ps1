# Deep audit of problems 1-200: identify real issues needing fixes
$problems = Get-Content "$PSScriptRoot\..\data\problems.json" -Raw | ConvertFrom-Json

$targetIds = 1..200
$issues = @()

foreach ($p in $problems) {
    if ($p.id -notin $targetIds) { continue }
    if ($p.status -eq 'duplicate') { continue }

    $myIssues = @()

    # 1. Check statement quality
    $stmt = if ($p.statement) { $p.statement } else { '' }
    $sol = if ($p.solution) { $p.solution } else { '' }

    # Vague/empty statement
    if ($stmt.Length -lt 30) { $myIssues += "EMPTY_STATEMENT" }
    elseif ($stmt.Length -lt 80) { $myIssues += "SHORT_STATEMENT($($stmt.Length))" }

    # Statement is just title repeated
    if ($stmt -and $p.title -and ($stmt.Trim().ToLower() -eq $p.title.Trim().ToLower())) { $myIssues += "STMT_IS_TITLE" }

    # 2. Check for real formatting problems (not just unicode math)
    # Raw HTML
    if ($stmt -match '<[a-zA-Z][^>]*>' -or $sol -match '<[a-zA-Z][^>]*>') { $myIssues += "HAS_HTML" }

    # Broken LaTeX: unmatched $$ (count $ signs, should be even)
    $stmtDollars = ([regex]::Matches($stmt, '(?<!\$)\$(?!\$)')).Count
    $solDollars = ([regex]::Matches($sol, '(?<!\$)\$(?!\$)')).Count
    if ($stmtDollars % 2 -ne 0) { $myIssues += "UNMATCHED_DOLLAR_STMT" }
    if ($solDollars % 2 -ne 0) { $myIssues += "UNMATCHED_DOLLAR_SOL" }

    # Garbled encoding (actual mojibake, not math symbols)
    # Check for sequences of 3+ non-ASCII chars that aren't valid LaTeX/unicode math
    $garbledPattern = '[\xC0-\xFF][\x80-\xBF]{2,}'
    if ($stmt -match $garbledPattern -or $sol -match $garbledPattern) { $myIssues += "MOJIBAKE" }

    # 3. Solution quality
    if ($p.status -eq 'complete' -and $sol.Length -lt 30) { $myIssues += "EMPTY_SOLUTION" }
    if ($sol -match '(?i)template|TODO|placeholder|lorem ipsum') { $myIssues += "TEMPLATE_SOLUTION" }

    # Solution is just bullets/one-liners (under 100 chars, no explanation)
    if ($p.status -eq 'complete' -and $sol.Length -gt 0 -and $sol.Length -lt 100) { $myIssues += "THIN_SOLUTION($($sol.Length))" }

    # 4. Category/type mismatch
    $cat = $p.category
    $type = $p.type

    # Coding category should be coding type
    if ($cat -eq 'coding' -and $type -ne 'coding') { $myIssues += "TYPE_MISMATCH(cat=$cat,type=$type)" }
    # Brain-teaser category should be brain-teaser type
    if ($cat -eq 'brain-teaser' -and $type -ne 'brain-teaser') { $myIssues += "TYPE_MISMATCH(cat=$cat,type=$type)" }
    # Options-pricing with type 'calculation' when it should be 'conceptual'
    if ($cat -eq 'options-pricing' -and $stmt -match '(?i)explain|describe|discuss|what are|list the|assumptions') {
        if ($type -ne 'conceptual' -and $type -ne 'open-ended') { $myIssues += "SHOULD_BE_CONCEPTUAL" }
    }

    # 5. Tags check
    if (-not $p.tags -or @($p.tags).Count -eq 0) { $myIssues += "NO_TAGS" }

    # 6. Title quality
    if ($p.title.Length -lt 10) { $myIssues += "SHORT_TITLE" }
    if ($p.title -match '^\d+\.' -or $p.title -match '^Problem \d+') { $myIssues += "NUMBERED_TITLE" }
    if ($p.title.Length -gt 100) { $myIssues += "LONG_TITLE($($p.title.Length))" }

    # 7. Multi-problem detection (statement contains multiple numbered sub-problems that should be separate)
    $subProblems = ([regex]::Matches($stmt, '(?m)^\s*\d+\.\s')).Count
    if ($subProblems -ge 3) { $myIssues += "MULTI_PROBLEM($subProblems)" }

    # 8. Wrong difficulty
    if ($p.difficulty -notin @('easy', 'medium', 'hard')) { $myIssues += "BAD_DIFFICULTY($($p.difficulty))" }

    if ($myIssues.Count -gt 0) {
        $titleShort = if ($p.title.Length -gt 60) { $p.title.Substring(0, 57) + '...' } else { $p.title }
        [Console]::Out.WriteLine("ID $($p.id): $titleShort")
        [Console]::Out.WriteLine("  Category: $cat | Type: $type | Diff: $($p.difficulty) | Status: $($p.status)")
        [Console]::Out.WriteLine("  Issues: $($myIssues -join ', ')")
        [Console]::Out.WriteLine("  Stmt: $($stmt.Substring(0, [math]::Min(120, $stmt.Length)))...")
        if ($sol.Length -gt 0) {
            [Console]::Out.WriteLine("  Sol: $($sol.Substring(0, [math]::Min(80, $sol.Length)))...")
        }
        [Console]::Out.WriteLine("")
        $issues += @{ id = $p.id; title = $p.title; issues = $myIssues; category = $cat; type = $type }
    }
}

[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("SUMMARY: $($issues.Count) problems with issues out of $($targetIds.Count) checked")
$issueCounts = @{}
foreach ($item in $issues) {
    foreach ($iss in $item.issues) {
        $tag = ($iss -split '\(')[0]
        if (-not $issueCounts.ContainsKey($tag)) { $issueCounts[$tag] = 0 }
        $issueCounts[$tag]++
    }
}
foreach ($entry in ($issueCounts.GetEnumerator() | Sort-Object Value -Descending)) {
    [Console]::Out.WriteLine("  $($entry.Key): $($entry.Value)")
}
