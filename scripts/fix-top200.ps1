# Fix quality issues in problems 1-200 and user-reported problems
# Issues: formatting, tags, types, solutions, duplicates, mojibake

$problemsPath = "$PSScriptRoot\..\data\problems.json"
[Console]::Out.WriteLine("Loading problems.json...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
[Console]::Out.WriteLine("  Total: $($problems.Count)")

$fixCount = 0

function Fix-Problem($id, $changes) {
    $script:fixCount++
    $idx = -1
    for ($i = 0; $i -lt $script:problems.Count; $i++) {
        if ($script:problems[$i].id -eq $id) { $idx = $i; break }
    }
    if ($idx -eq -1) { [Console]::Out.WriteLine("  WARN: ID $id not found"); return }
    $p = $script:problems[$idx]

    foreach ($key in $changes.Keys) {
        $val = $changes[$key]
        if ($p.PSObject.Properties[$key]) {
            $p.$key = $val
        } else {
            $p | Add-Member -NotePropertyName $key -NotePropertyValue $val -Force
        }
    }
    [Console]::Out.WriteLine("  Fixed ID $id - $($p.title)")
}

# ============ USER-REPORTED ISSUES ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== Fixing user-reported issues ===")

# ID 231, 24, 294, 895 are essentially equivalent (biased coin -> fair coin)
# Keep 24 (original, well-formulated), mark 231, 294, 895 as duplicate
# But 294 has a different angle (worst-case minimization), and 895 is more open-ended
# Mark 231 and 895 as duplicates of 24 (they're the same Von Neumann trick)
Fix-Problem 231 @{ status = 'duplicate' }
Fix-Problem 895 @{ status = 'duplicate' }
# 294 is actually different - it asks about worst-case optimization for extreme p, keep it but fix mojibake
# Fix the mojibake in ID 294 statement
$p294 = $problems | Where-Object { $_.id -eq 294 }
if ($p294 -and $p294.statement) {
    $p294.statement = "Use a biased coin with `$p\approx 0.99`$ to simulate a fair outcome. Design a scheme that minimizes the *worst-case* number of tosses (compare von Neumann's method, Elias, and stopping rules tailored to extreme `$p`$)."
}
[Console]::Out.WriteLine("  Fixed ID 294 - removed mojibake from statement")

# ID 752: Reversi - should be coding, not probability
Fix-Problem 752 @{ category = 'coding'; type = 'coding'; tags = @('simulation', 'board-game'); roles = @('SWE') }

# ID 995: System Design - too vague, only 89 chars
Fix-Problem 995 @{
    statement = "Design a large-scale system for storing and serving market data (tick-by-tick trades, quotes, order book snapshots) that supports both real-time streaming and historical batch queries for building quantitative models. Your design should address: (1) Data ingestion from multiple exchange feeds; (2) Storage architecture for time-series data; (3) Query patterns for backtesting and research; (4) Scalability and latency requirements."
    difficulty = 'hard'
}

# ID 738: Multiple problems crammed into one - this is a meta-problem describing interview rounds
Fix-Problem 738 @{ status = 'duplicate'; type = 'coding' }
[Console]::Out.WriteLine("  Marked ID 738 as duplicate (meta-problem describing interview rounds, not a real problem)")

# ID 331: Should be open-ended, not calculation
Fix-Problem 331 @{ type = 'open-ended'; category = 'statistics'; tags = @('causal-inference', 'regression', 'experiment-design') }

# ID 2566: Bad title, bad description
Fix-Problem 2566 @{
    title = 'Marble Parity Puzzle'
    statement = "A bucket contains an odd number of white marbles and some number of black marbles. Outside the bucket you have infinitely many black marbles. You repeat the following procedure: randomly pick 2 marbles from the bucket. If at least one is black, put one black marble outside the bucket and put the other marble back in. If both are white, remove both and put one black marble into the bucket. What is the color of the last marble remaining in the bucket?"
}

# ID 129: Wrong type (calculation -> conceptual), solution has severe mojibake
Fix-Problem 129 @{ type = 'conceptual' }
# Fix the mojibake solution for 129
$p129 = $problems | Where-Object { $_.id -eq 129 }
if ($p129) {
    $p129.solution = @"
## Key Assumptions of the Black-Scholes Model

**1. Constant Volatility:** The model assumes volatility `$\sigma$` is constant over the option's life. In practice, volatility varies (volatility smile/skew). This leads to mispricing, especially for OTM options.

**2. Log-Normal Stock Prices:** Returns are normally distributed with no jumps. Reality shows fat tails and occasional jumps (earnings, crashes). This causes the model to underestimate tail risk.

**3. Continuous Trading:** The model assumes continuous, frictionless trading for delta hedging. In practice, discrete rebalancing introduces hedging error proportional to `$\sqrt{\Delta t}$`.

**4. No Transaction Costs:** Real markets have bid-ask spreads and commissions. Frequent rebalancing for delta hedging becomes costly, making perfect replication impossible.

**5. Constant Risk-Free Rate:** Interest rates are assumed fixed. Rate volatility affects long-dated options and interest rate derivatives.

**6. No Dividends (basic model):** The basic model ignores dividends. Merton's extension handles continuous dividends; discrete dividends require more complex adjustments.

**7. No Arbitrage:** Markets are assumed efficient with no arbitrage opportunities. While approximately true for liquid markets, temporary mispricings do occur.

**8. European Exercise Only:** The basic model prices European options. American options require modifications (e.g., binomial trees, finite differences) for early exercise.
"@
}
[Console]::Out.WriteLine("  Fixed ID 129 - replaced mojibake solution")

# ID 468: Solution has bad formatting (starts with "$ = E[...")
Fix-Problem 468 @{ tags = @('options-pricing', 'expected-value') }
$p468 = $problems | Where-Object { $_.id -eq 468 }
if ($p468 -and $p468.solution -match '^\*\*Approach') {
    # Fix the broken LaTeX: "$ = E[" should be "$C = E["
    $p468.solution = $p468.solution -replace '\$\s*=\s*E\[', '$C = E['
    [Console]::Out.WriteLine("  Fixed ID 468 - fixed broken LaTeX in solution")
}

# ID 2275: Bad formatting (\unif{0}{a} not valid LaTeX)
$p2275 = $problems | Where-Object { $_.id -eq 2275 }
if ($p2275) {
    $p2275.statement = $p2275.statement -replace '\\unif\{([^}]*)\}\{([^}]*)\}', 'U($1, $2)'
    $p2275.solution = $p2275.solution -replace '\\unif\{([^}]*)\}\{([^}]*)\}', 'U($1, $2)'
    [Console]::Out.WriteLine("  Fixed ID 2275 - replaced \unif macro with U()")
}

# ID 2497: Bad formatting (\unif, \ev, \binomial macros)
$p2497 = $problems | Where-Object { $_.id -eq 2497 }
if ($p2497) {
    $p2497.statement = $p2497.statement -replace '\\unif\{([^}]*)\}\{([^}]*)\}', 'U($1, $2)' -replace '\\ev\{([^}]*)\}', 'E[$1]' -replace '\\prob\{([^}]*)\}', 'P($1)' -replace '\\binomial\{([^}]*)\}\{([^}]*)\}', '\text{Bin}($1, $2)'
    $p2497.solution = $p2497.solution -replace '\\unif\{([^}]*)\}\{([^}]*)\}', 'U($1, $2)' -replace '\\ev\{([^}]*)\}', 'E[$1]' -replace '\\prob\{([^}]*)\}', 'P($1)' -replace '\\binomial\{([^}]*)\}\{([^}]*)\}', '\text{Bin}($1, $2)'
    [Console]::Out.WriteLine("  Fixed ID 2497 - replaced custom LaTeX macros")
}

# ID 1935: Same custom macro issue
$p1935 = $problems | Where-Object { $_.id -eq 1935 }
if ($p1935) {
    $p1935.statement = $p1935.statement -replace '\\binomial\{([^}]*)\}\{([^}]*)\}', '\text{Bin}($1, $2)' -replace '\\prob\{([^}]*)\}', 'P($1)' -replace '\\ev\{([^}]*)\}', 'E[$1]'
    $p1935.solution = $p1935.solution -replace '\\binomial\{([^}]*)\}\{([^}]*)\}', '\text{Bin}($1, $2)' -replace '\\prob\{([^}]*)\}', 'P($1)' -replace '\\ev\{([^}]*)\}', 'E[$1]'
    [Console]::Out.WriteLine("  Fixed ID 1935 - replaced custom LaTeX macros")
}

# ID 2592: Wrong problem description (should be "uncorrelated")
Fix-Problem 2592 @{
    title = 'Variance of Sum of Independent Random Variables'
    statement = "Show that the variance of the sum of two independent random variables is the sum of the variances. That is, prove that if `$X$` and `$Y$` are independent, then `$\text{Var}(X + Y) = \text{Var}(X) + \text{Var}(Y)$`. Discuss whether the result holds when `$X$` and `$Y$` are merely uncorrelated rather than independent."
    type = 'proof'
}

# ID 26: Solution formatting - let's check it
# (User said bad solution formatting - the solution shown above looks fine, just check)

# ID 411: Bad solution - check the broken LaTeX
$p411 = $problems | Where-Object { $_.id -eq 411 }
if ($p411 -and $p411.solution -match '\$\s*-\s*N!') {
    $p411.solution = $p411.solution -replace '\$\s*-\s*N!\s*\\cdot', '$$xy - N! \cdot'
    [Console]::Out.WriteLine("  Fixed ID 411 - fixed broken LaTeX in solution")
}

# ============ AUDIT-FLAGGED FIXES ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== Fixing audit-flagged issues ===")

# ID 58: Should be conceptual/proof, not calculation (it says "show that")
Fix-Problem 58 @{ type = 'proof' }

# ID 124: Monte Carlo - should be conceptual (says "describe how to")
Fix-Problem 124 @{ type = 'conceptual' }

# ID 125: Unmatched dollar signs - these are from "$100" "$120" "$80" in text
# The dollar signs here are currency, not LaTeX. Fix by escaping.
$p125 = $problems | Where-Object { $_.id -eq 125 }
if ($p125) {
    $p125.statement = $p125.statement -replace '(?<!\$)\$(\d+)', '\$$1'
    [Console]::Out.WriteLine("  Fixed ID 125 - escaped currency dollar signs in statement")
}

# ID 131: Delta of digital option - should be calculation (it asks to compute delta)
# Actually audit says "should be conceptual" but the problem asks to derive the delta - that's calculation. Keep it.

# ID 134: Carr-Madan - should be conceptual (says "explain")
Fix-Problem 134 @{ type = 'conceptual' }

# ID 165: Unmatched dollar signs from currency
$p165 = $problems | Where-Object { $_.id -eq 165 }
if ($p165) {
    $p165.statement = $p165.statement -replace '(?<!\$)\$\\?\$(\d+)', '\$$1'
    $p165.solution = $p165.solution -replace '(?<!\$)\$\\?\$(\d+)', '\$$1'
    [Console]::Out.WriteLine("  Fixed ID 165 - escaped currency dollar signs")
}

# ID 192, 193: HTML in solutions - clean up
foreach ($htmlId in @(192, 193)) {
    $ph = $problems | Where-Object { $_.id -eq $htmlId }
    if ($ph) {
        $ph.statement = $ph.statement -replace '<[^>]+>', ''
        $ph.solution = $ph.solution -replace '<[^>]+>', ''
        [Console]::Out.WriteLine("  Fixed ID $htmlId - removed HTML tags")
    }
}

# ============ GLOBAL FIXES: Custom LaTeX macros ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== Global fix: custom LaTeX macros ===")

$macroFixCount = 0
foreach ($p in $problems) {
    $changed = $false

    if ($p.statement -and $p.statement -match '\\(unif|ev|prob|binomial|expected)\{') {
        $p.statement = $p.statement -replace '\\unif\{([^}]*)\}\{([^}]*)\}', 'U($1, $2)'
        $p.statement = $p.statement -replace '\\ev\{([^}]*)\}', 'E[$1]'
        $p.statement = $p.statement -replace '\\expected\{([^}]*)\}', 'E[$1]'
        $p.statement = $p.statement -replace '\\prob\{([^}]*)\}', 'P($1)'
        $p.statement = $p.statement -replace '\\binomial\{([^}]*)\}\{([^}]*)\}', '\text{Bin}($1, $2)'
        $changed = $true
    }
    if ($p.solution -and $p.solution -match '\\(unif|ev|prob|binomial|expected)\{') {
        $p.solution = $p.solution -replace '\\unif\{([^}]*)\}\{([^}]*)\}', 'U($1, $2)'
        $p.solution = $p.solution -replace '\\ev\{([^}]*)\}', 'E[$1]'
        $p.solution = $p.solution -replace '\\expected\{([^}]*)\}', 'E[$1]'
        $p.solution = $p.solution -replace '\\prob\{([^}]*)\}', 'P($1)'
        $p.solution = $p.solution -replace '\\binomial\{([^}]*)\}\{([^}]*)\}', '\text{Bin}($1, $2)'
        $changed = $true
    }

    if ($changed) { $macroFixCount++ }
}
[Console]::Out.WriteLine("  Fixed custom macros in $macroFixCount problems")

# ============ GLOBAL FIXES: Mojibake in solutions ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== Checking for mojibake solutions ===")
$mojibakeCount = 0
foreach ($p in $problems) {
    if ($p.solution -and $p.solution -match 'A\xC3\xA2|A\+\?T|A\?\?s|A\?\?z') {
        # This is severe mojibake - mark as incomplete to be regenerated
        if ($p.id -ne 129) {  # 129 already fixed above
            $p.solution = ''
            $p.status = 'incomplete'
            $mojibakeCount++
            [Console]::Out.WriteLine("  Cleared mojibake solution for ID $($p.id) - $($p.title)")
        }
    }
}
[Console]::Out.WriteLine("  Cleared $mojibakeCount mojibake solutions")

# ============ REPORT ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("TOTAL FIXES APPLIED: $fixCount explicit + $macroFixCount macro + $mojibakeCount mojibake")
[Console]::Out.WriteLine("=========================================")

# Final status
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
