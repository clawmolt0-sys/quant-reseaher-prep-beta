# Comprehensive audit of ALL problems — find every systemic issue
# Outputs categorized issue list with counts

$problemsPath = "$PSScriptRoot\..\data\problems.json"
[Console]::Out.WriteLine("Loading problems.json...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
$active = @($problems | Where-Object { $_.status -ne 'duplicate' })
[Console]::Out.WriteLine("  Active problems: $($active.Count)")

$issues = @{}
function Add-Issue($category, $id, $detail) {
    if (-not $issues.ContainsKey($category)) { $issues[$category] = @() }
    $issues[$category] += @{ id = $id; detail = $detail }
}

foreach ($p in $active) {
    $stmt = if ($p.statement) { $p.statement } else { '' }
    $sol = if ($p.solution) { $p.solution } else { '' }
    $title = if ($p.title) { $p.title } else { '' }

    # ====== 1. BROKEN TITLES ======
    # Title starts with lowercase or fragment words
    if ($title -match '^(of |the |and |is |are |to |in |for |a |an |that |with |from |by |at |on |or |as |it |if |be |do |so |but |not |we |you |he |she )') {
        Add-Issue 'BROKEN_TITLE_FRAGMENT' $p.id "Title: $title"
    }
    # Title ends with preposition/conjunction (truncated)
    if ($title -match '\s(the|and|or|of|to|in|for|with|a|an|is|are|that|which|from|by|at|on|as|if|but|not|into|than|its|this|these|those|when|where|how|what|who)\s*$') {
        Add-Issue 'BROKEN_TITLE_TRAILING' $p.id "Title: $title"
    }
    # Title is too long (over 80 chars — probably a sentence fragment)
    if ($title.Length -gt 80) {
        Add-Issue 'TITLE_TOO_LONG' $p.id "[$($title.Length) chars] $($title.Substring(0, 60))..."
    }

    # ====== 2. PLACEHOLDER STATEMENTS ======
    if ($stmt -match '^Solve this \w[\w\-]* problem:') {
        Add-Issue 'PLACEHOLDER_SOLVE_THIS' $p.id "Stmt: $stmt"
    }
    if ($stmt -match '^(A|The|Some|An)\s+(probability|math|coding|statistics|finance|combinatorics|optimization)\s+(problem|question)') {
        Add-Issue 'META_DESCRIPTION' $p.id "Stmt: $stmt"
    }

    # ====== 3. RAW LATEX MACROS (not rendered) ======
    if ($stmt -match '\\(corr|unif|ev|prob|binomial|expected|var|cov|indicator)\{' -or $sol -match '\\(corr|unif|ev|prob|binomial|expected|var|cov|indicator)\{') {
        $macro = $Matches[1]
        Add-Issue 'RAW_LATEX_MACRO' $p.id "Has \\$macro{} macro"
    }

    # ====== 4. BROKEN LATEX (unmatched dollars) ======
    $stmtDollars = ($stmt -split '\$').Count - 1
    if ($stmtDollars -gt 0 -and $stmtDollars % 2 -ne 0) {
        Add-Issue 'UNMATCHED_DOLLAR_STMT' $p.id "Statement has $stmtDollars dollar signs"
    }
    $solDollars = ($sol -split '\$').Count - 1
    if ($solDollars -gt 0 -and $solDollars % 2 -ne 0) {
        Add-Issue 'UNMATCHED_DOLLAR_SOL' $p.id "Solution has $solDollars dollar signs"
    }

    # ====== 5. HTML TAGS ======
    if ($stmt -match '<(?!code|/code|pre|/pre)[a-zA-Z][^>]*>' -or $sol -match '<(?!code|/code|pre|/pre)[a-zA-Z][^>]*>') {
        Add-Issue 'HAS_HTML' $p.id "Contains HTML tags"
    }

    # ====== 6. WRONG CATEGORY / TYPE ======
    # Coding problem not in coding category
    if ($stmt -match '(?i)(write a (function|program|code|script)|implement|given an array|return the|input:|output:|def |function\(|class\s+\w+|O\(n)' -and $p.category -ne 'coding' -and $p.type -ne 'coding') {
        if ($stmt -match '(?i)(write a function|implement.*function|given an array|def \w+\(|return the .* of)') {
            Add-Issue 'SHOULD_BE_CODING' $p.id "Category: $($p.category), has coding keywords"
        }
    }
    # Optimization problem in wrong category
    if ($stmt -match '(?i)(optim|minimize|maximize|linear program|constraint|feasib|lagrange|convex)' -and $p.category -eq 'probability') {
        if ($stmt -notmatch '(?i)(probability|P\(|expected|random|dice|coin|card)') {
            Add-Issue 'SHOULD_BE_OPTIMIZATION' $p.id "Category: probability, stmt is about optimization"
        }
    }

    # ====== 7. EMPTY / VERY SHORT STATEMENTS ======
    if ($stmt.Length -eq 0 -and $p.status -eq 'complete') {
        Add-Issue 'EMPTY_STMT_COMPLETE' $p.id "Complete but no statement"
    }
    if ($stmt.Length -gt 0 -and $stmt.Length -lt 30 -and $stmt -notmatch '\$') {
        Add-Issue 'VERY_SHORT_STMT' $p.id "[$($stmt.Length) chars] $stmt"
    }

    # ====== 8. MOJIBAKE / ENCODING ISSUES ======
    if ($stmt -match 'A\?\?[sTz]|A\+\?T|\.Groups\[1\]' -or $sol -match 'A\?\?[sTz]|A\+\?T|\.Groups\[1\]') {
        Add-Issue 'MOJIBAKE' $p.id "Has mojibake patterns"
    }
    # UTF8 garbled
    if ($stmt -match '[\xC3][\x80-\xBF]' -or $sol -match '[\xC3][\x80-\xBF]') {
        Add-Issue 'UTF8_GARBLED' $p.id "Possible UTF8 encoding issue"
    }

    # ====== 9. DUPLICATE TITLES (exact match, different IDs) ======
    # (handled separately below)

    # ====== 10. NO TAGS ======
    $hasTags = $false
    if ($p.tags) {
        $validTags = @($p.tags | Where-Object { $_ -and $_.Length -gt 0 })
        if ($validTags.Count -gt 0) { $hasTags = $true }
    }
    if (-not $hasTags -and $p.status -eq 'complete') {
        Add-Issue 'NO_TAGS_COMPLETE' $p.id "Complete problem with no tags"
    }

    # ====== 11. SOLUTION ISSUES ======
    if ($sol -match '^\*\*Approach') {
        # Check if solution is just "**Approach:**" header with nothing useful
        if ($sol.Length -lt 100) {
            Add-Issue 'STUB_SOLUTION' $p.id "Solution stub: $($sol.Substring(0, [math]::Min(60, $sol.Length)))"
        }
    }
    # Solution starts with raw "Solution:" which is redundant
    if ($sol -match '^Solution:\s*$' -and $sol.Length -lt 20) {
        Add-Issue 'EMPTY_SOLUTION_HEADER' $p.id "Solution is just 'Solution:'"
    }

    # ====== 12. TITLE IS FIRST LINE OF STATEMENT ======
    if ($title.Length -gt 30 -and $stmt.Length -gt 0) {
        $stmtFirst = ($stmt -split '\n')[0].Trim()
        if ($stmtFirst.Length -gt 20) {
            $titleNorm = $title.ToLower() -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
            $stmtNorm = $stmtFirst.ToLower() -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
            if ($titleNorm.Length -gt 20 -and $stmtNorm.StartsWith($titleNorm.Substring(0, [math]::Min(25, $titleNorm.Length)))) {
                Add-Issue 'TITLE_IS_STMT' $p.id "Title duplicates statement start"
            }
        }
    }
}

# ====== DUPLICATE TITLE CHECK ======
$titleIndex = @{}
foreach ($p in $active) {
    $tfp = $p.title.ToLower() -replace '[^a-z0-9]', ''
    if ($tfp.Length -lt 8) { continue }
    if ($titleIndex.ContainsKey($tfp)) {
        $existingId = $titleIndex[$tfp]
        Add-Issue 'DUPLICATE_TITLE' $p.id "Same title as ID $existingId : $($p.title)"
    } else {
        $titleIndex[$tfp] = $p.id
    }
}

# ====== REPORT ======
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("COMPREHENSIVE AUDIT RESULTS")
[Console]::Out.WriteLine("=========================================")

$totalIssues = 0
foreach ($cat in ($issues.Keys | Sort-Object)) {
    $count = $issues[$cat].Count
    $totalIssues += $count
    [Console]::Out.WriteLine("")
    [Console]::Out.WriteLine("--- $cat : $count ---")
    $sample = @($issues[$cat] | Select-Object -First 8)
    foreach ($item in $sample) {
        $detailShort = if ($item.detail.Length -gt 80) { $item.detail.Substring(0, 77) + '...' } else { $item.detail }
        [Console]::Out.WriteLine("  ID $($item.id): $detailShort")
    }
    if ($count -gt 8) { [Console]::Out.WriteLine("  ... and $($count - 8) more") }
}

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("TOTAL ISSUES: $totalIssues")
[Console]::Out.WriteLine("=========================================")

# Output IDs for each category for batch fixing
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== IDs BY CATEGORY (for batch fix) ===")
foreach ($cat in ($issues.Keys | Sort-Object)) {
    $ids = @($issues[$cat] | ForEach-Object { $_.id })
    [Console]::Out.WriteLine("${cat}: $($ids -join ',')")
}
