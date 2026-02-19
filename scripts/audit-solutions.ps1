# Audit solution quality for problems 1-200
# Check for: bad formatting, thin solutions, wrong answers, garbled text
$problems = Get-Content "$PSScriptRoot\..\data\problems.json" -Raw | ConvertFrom-Json

$issues = @()
$good = 0
$checked = 0

foreach ($p in $problems) {
    if ($p.id -lt 1 -or $p.id -gt 200) { continue }
    if ($p.status -eq 'duplicate') { continue }
    $checked++

    $sol = if ($p.solution) { $p.solution } else { '' }
    $stmt = if ($p.statement) { $p.statement } else { '' }
    $myIssues = @()

    # Solution length
    if ($sol.Length -lt 30) { $myIssues += "NO_SOL" }
    elseif ($sol.Length -lt 150) { $myIssues += "THIN_SOL($($sol.Length))" }

    # Check for garbled/mojibake chars in solution
    if ($sol -match '[\xC0-\xFF]{3,}' -and $sol -notmatch '\\[a-zA-Z]') {
        $myIssues += "GARBLED_SOL"
    }

    # Check solution starts with "**Approach:**" template (generated solutions are OK but check quality)
    if ($sol -match '^\*\*Approach:\*\*' -and $sol.Length -lt 300) { $myIssues += "SHALLOW_TEMPLATE" }

    # Check for broken LaTeX in solution: unmatched \begin without \end
    if ($sol -match '\\begin\{' -and -not ($sol -match '\\end\{')) { $myIssues += "BROKEN_LATEX_ENV" }

    # Check solution has actual math/explanation (not just bullet points)
    $hasFormula = $sol -match '\$[^$]+\$' -or $sol -match '\$\$[^$]+\$\$'
    $hasExplanation = $sol.Length -gt 200
    if (-not $hasFormula -and -not $hasExplanation -and $sol.Length -gt 0) { $myIssues += "NO_MATH_OR_DETAIL" }

    # Check tags are meaningful
    if (@($p.tags).Count -eq 0 -and $p.category -ne 'coding') { $myIssues += "NO_TAGS" }

    # Check category makes sense
    if ($p.category -eq 'statistics' -and $stmt -match 'E\[max|E\[min|expected.*max|expected.*min') {
        if ($p.category -ne 'expectation') { $myIssues += "SHOULD_BE_EXPECTATION" }
    }

    if ($myIssues.Count -gt 0) {
        $titleShort = if ($p.title.Length -gt 55) { $p.title.Substring(0, 52) + '...' } else { $p.title }
        [Console]::Out.WriteLine("ID $($p.id): $titleShort | $($myIssues -join ', ')")
        $issues += @{ id = $p.id; issues = $myIssues }
    } else {
        $good++
    }
}

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Checked: $checked | Good: $good | Issues: $($issues.Count)")
$issueTypes = @{}
foreach ($item in $issues) {
    foreach ($iss in $item.issues) {
        $tag = ($iss -split '\(')[0]
        if (-not $issueTypes.ContainsKey($tag)) { $issueTypes[$tag] = 0 }
        $issueTypes[$tag]++
    }
}
[Console]::Out.WriteLine("Issue breakdown:")
foreach ($e in ($issueTypes.GetEnumerator() | Sort-Object Value -Descending)) {
    [Console]::Out.WriteLine("  $($e.Key): $($e.Value)")
}
