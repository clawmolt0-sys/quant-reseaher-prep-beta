# Expand vague/short problem statements into properly formatted descriptions
# Uses a standardized format template per problem type
#
# Usage: powershell -File expand-statements.ps1
# Or:    powershell -File expand-statements.ps1 -MaxProblems 50
#
# This script identifies problems with vague one-liner statements and generates
# expanded versions. It does NOT call an LLM — it applies rule-based expansion
# where possible and flags the rest for manual/LLM review.

param(
    [int]$MaxProblems = 100
)

$problemsPath = "$PSScriptRoot\..\data\problems.json"
[Console]::Out.WriteLine("Loading problems.json...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json

# ============ IDENTIFY VAGUE STATEMENTS ============

# A statement is "vague" if:
# 1. It's under 80 chars AND doesn't contain math notation ($...$)
# 2. It's a meta-description ("A problem was asked...", "There were some questions...")
# 3. It's just the title restated as a question

$vague = @()
$fixable = @()

foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    if (-not $p.statement -or $p.statement.Length -le 5) { continue }

    $stmt = $p.statement.Trim()
    $isVague = $false
    $reason = ''

    # Meta-descriptions (definitely bad)
    if ($stmt -match '(?i)^(a|the|some|an)\s+(probability|math|coding|statistics|finance|combinatorics)\s+(problem|question|challenge)\s+(was|were|has been)') {
        $isVague = $true
        $reason = 'META_DESCRIPTION'
    }
    elseif ($stmt -match '(?i)(have been forgotten|were not recorded|details are missing|not available)') {
        $isVague = $true
        $reason = 'MISSING_DETAILS'
    }
    elseif ($stmt -match '(?i)^(a|an)\s+\w+\s+(problem|question)\s+(was asked|appeared|came up)') {
        $isVague = $true
        $reason = 'META_DESCRIPTION'
    }
    # Very short non-math statements
    elseif ($stmt.Length -lt 50 -and $stmt -notmatch '\$') {
        # Check if it's just a simple question (might be OK for conceptual)
        if ($p.type -ne 'conceptual' -and $p.type -ne 'open-ended') {
            $isVague = $true
            $reason = 'TOO_SHORT'
        }
    }
    # Title restated
    elseif ($stmt.Length -lt 80) {
        $titleNorm = $p.title.ToLower() -replace '[^a-z0-9\s]', ''
        $stmtNorm = $stmt.ToLower() -replace '[^a-z0-9\s]', ''
        $titleWords = @($titleNorm -split '\s+' | Where-Object { $_.Length -gt 2 })
        $stmtWords = @($stmtNorm -split '\s+' | Where-Object { $_.Length -gt 2 })
        if ($titleWords.Count -gt 0 -and $stmtWords.Count -gt 0) {
            $overlap = 0
            foreach ($w in $titleWords) { if ($stmtWords -contains $w) { $overlap++ } }
            $jaccard = $overlap / [math]::Max(1, ($titleWords.Count + $stmtWords.Count - $overlap))
            if ($jaccard -ge 0.7 -and $stmt -notmatch '\$') {
                $isVague = $true
                $reason = 'TITLE_RESTATE'
            }
        }
    }

    if ($isVague) {
        $vague += @{ problem = $p; reason = $reason }
    }
}

[Console]::Out.WriteLine("Found $($vague.Count) vague statements")
[Console]::Out.WriteLine("")

# ============ CATEGORIZE AND REPORT ============

$byReason = @{}
foreach ($v in $vague) {
    $r = $v.reason
    if (-not $byReason.ContainsKey($r)) { $byReason[$r] = @() }
    $byReason[$r] += $v
}

foreach ($r in ($byReason.Keys | Sort-Object)) {
    [Console]::Out.WriteLine("$r : $($byReason[$r].Count)")
    $sample = @($byReason[$r] | Select-Object -First 5)
    foreach ($v in $sample) {
        $p = $v.problem
        $stmtShort = if ($p.statement.Length -gt 70) { $p.statement.Substring(0, 67) + '...' } else { $p.statement }
        [Console]::Out.WriteLine("  ID $($p.id) [$($p.category)]: $stmtShort")
    }
    [Console]::Out.WriteLine("")
}

# ============ AUTO-FIX: Mark truly bad ones as title-only ============
$autoFixed = 0
foreach ($v in $vague) {
    $p = $v.problem
    if ($v.reason -eq 'META_DESCRIPTION' -or $v.reason -eq 'MISSING_DETAILS') {
        # These are garbage — the statement is just "A problem was asked..."
        # Clear the statement, mark as title-only incomplete
        $p.statement = ''
        if ($p.status -eq 'complete' -and (-not $p.solution -or $p.solution.Length -lt 50)) {
            $p.status = 'incomplete'
        }
        $autoFixed++
    }
}

[Console]::Out.WriteLine("Auto-fixed (cleared garbage meta-descriptions): $autoFixed")

# ============ GENERATE PROMPT TEMPLATE ============
# This is the prompt template to use with an LLM to expand remaining vague statements

$promptTemplate = @"
## Problem Description Agent - Prompt Template

Use this prompt with an LLM (GPT-4, Claude, etc.) to expand vague one-liner
problem statements into properly formatted descriptions.

### System Prompt:
You are a quant interview problem writer. Given a problem title, category, and
vague description, write a clear, complete problem statement.

### Rules:
1. The statement must be self-contained — a reader should understand exactly
   what to solve without seeing the title
2. Use LaTeX notation for math (wrapped in dollar signs)
3. Include all necessary definitions and constraints
4. For calculation problems: state what quantity to compute
5. For proof problems: state what to prove
6. For coding problems: specify input/output format, constraints, examples
7. For conceptual problems: ask a specific question
8. Keep it concise but complete (80-300 chars typically)
9. Do NOT include the answer or solution hints

### Format by Category:
- **probability**: Define the random setup, state what probability to find
- **expectation**: Define variables, state what expected value to compute
- **coding**: Specify function signature, input constraints, expected output, example
- **brain-teaser**: Set up the scenario, state the goal clearly
- **statistics**: Define the data/distributions, state what to test/estimate
- **finance**: Define the instrument/model, state what to price/hedge/analyze
- **combinatorics**: Define the objects, state what to count/prove
- **linear-algebra**: Define the matrices/vectors, state what to compute/prove

### Example Input:
Title: Fast Exponentiation by Squaring
Category: coding
Vague Statement: How can you optimally implement a function to raise a number to an exponential?

### Example Output:
Implement a function `power(base, exponent)` that computes base^exponent
efficiently, where exponent is a non-negative integer. Your solution should
run in O(log n) time. Explain the key idea and provide both recursive and
iterative implementations.
"@

$promptPath = "$PSScriptRoot\DESCRIPTION_AGENT_PROMPT.md"
$promptTemplate | Set-Content $promptPath -Encoding UTF8
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Prompt template saved to: $promptPath")

# ============ SAVE ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Saving problems.json...")
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8
$size = [math]::Round((Get-Item $problemsPath).Length / 1KB)
[Console]::Out.WriteLine("  File size: ${size} KB")

$statuses = $problems | Group-Object status | Sort-Object Count -Descending
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Status breakdown:")
foreach ($s in $statuses) { [Console]::Out.WriteLine("  $($s.Name): $($s.Count)") }

# List remaining short-statement IDs for LLM processing
$remaining = @($vague | Where-Object { $_.reason -eq 'TOO_SHORT' -or $_.reason -eq 'TITLE_RESTATE' } | ForEach-Object { $_.problem.id })
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Remaining problems needing LLM expansion: $($remaining.Count)")
if ($remaining.Count -gt 0) {
    [Console]::Out.WriteLine("  IDs: $($remaining[0..([math]::Min(29, $remaining.Count-1))] -join ', ')...")
}
[Console]::Out.WriteLine("Done.")
