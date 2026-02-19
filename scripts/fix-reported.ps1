# Fix user-reported problems: 986, 2005, 2728, 2556

$problemsPath = "$PSScriptRoot\..\data\problems.json"
[Console]::Out.WriteLine("Loading problems.json...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
[Console]::Out.WriteLine("  Total: $($problems.Count)")

$byId = @{}
foreach ($p in $problems) { $byId[$p.id] = $p }

# ========== ID 986: Mark as duplicate of 525 (Magic Square - same problem) ==========
$p986 = $byId[986]
$p525 = $byId[525]
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== ID 986 -> duplicate of 525 ===")
[Console]::Out.WriteLine("  986: $($p986.title)")
[Console]::Out.WriteLine("  525: $($p525.title)")

# Merge companies from 986 into 525
if ($p986.companies) {
    foreach ($c in $p986.companies) {
        if ($c -notin @($p525.companies)) { $p525.companies = @($p525.companies) + $c }
    }
}
# Merge tags
if ($p986.tags) {
    foreach ($t in $p986.tags) {
        if ($t -and $t -notin @($p525.tags)) { $p525.tags = @($p525.tags) + $t }
    }
}
$p986.status = 'duplicate'
[Console]::Out.WriteLine("  Done - 986 marked duplicate, companies merged into 525")

# ========== ID 2005: Fix title + fix \corr formatting ==========
$p2005 = $byId[2005]
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== ID 2005: Fix title and formatting ===")
[Console]::Out.WriteLine("  Old title: $($p2005.title)")

$p2005.title = "Correlation of Sums of Uncorrelated Variables"

# Fix statement - make it proper
$p2005.statement = @"
Let `$X_1, X_2, X_3`$ be three uncorrelated random variables with variances `$\sigma_1^2 = 4`$, `$\sigma_2^2 = 5`$, and `$\sigma_3^2 = 9`$.

Define `$U = X_1 + X_2`$ and `$V = X_1 + X_3`$.

Compute the correlation `$\text{Corr}(U, V)`$.
"@

# Fix solution - replace any \corr macros
if ($p2005.solution -match '\\corr') {
    $p2005.solution = $p2005.solution -replace '\\corr\{([^}]*)\}\{([^}]*)\}', '\text{Corr}($1, $2)'
    $p2005.solution = $p2005.solution -replace '\\corr', '\text{Corr}'
}

[Console]::Out.WriteLine("  New title: $($p2005.title)")
[Console]::Out.WriteLine("  Statement and solution formatting fixed")

# ========== ID 2728: Bad problem - vague statement, wrong category ==========
$p2728 = $byId[2728]
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== ID 2728: Fix title, statement, category ===")
[Console]::Out.WriteLine("  Old title: $($p2728.title)")
[Console]::Out.WriteLine("  Old category: $($p2728.category)")

$p2728.title = "Expected Value of Dice Rolling Game"
$p2728.category = "expectation"
$p2728.type = "calculation"
$p2728.tags = @("dice", "expected-value")

$p2728.statement = @"
You roll a fair six-sided die repeatedly until you roll a 6. Each time you roll, you receive a payment equal to the face value shown.

(a) What is the expected total payment you receive?

(b) Suppose you are offered two games:
- **Game A**: Pay `$\$10`$ to play the dice game described above.
- **Game B**: Pay `$\$5`$ to roll one die and receive `$\$1`$ times the face value.

Which game has a higher expected profit?
"@

[Console]::Out.WriteLine("  New title: $($p2728.title)")
[Console]::Out.WriteLine("  New category: expectation")
[Console]::Out.WriteLine("  Statement rewritten")

# ========== ID 2556: Expand vague one-line description ==========
$p2556 = $byId[2556]
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== ID 2556: Expand vague statement ===")
[Console]::Out.WriteLine("  Old statement: $($p2556.statement)")

$p2556.title = "Fast Exponentiation by Squaring"
$p2556.statement = @"
Implement a function `power(base, exponent)` that computes `$\text{base}^{\text{exponent}}`$ efficiently, where `exponent` is a non-negative integer.

Your solution should run in `$O(\log n)`$ time where `$n`$ is the exponent value, rather than the naive `$O(n)`$ approach of repeated multiplication.

Explain the key idea behind your approach and provide both recursive and iterative implementations.
"@

[Console]::Out.WriteLine("  New title: $($p2556.title)")
[Console]::Out.WriteLine("  Statement expanded with clear requirements")

# ========== Save ==========
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Saving...")
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8
$size = [math]::Round((Get-Item $problemsPath).Length / 1KB)
[Console]::Out.WriteLine("  problems.json: ${size} KB")

# Final status
$statuses = $problems | Group-Object status | Sort-Object Count -Descending
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Status breakdown:")
foreach ($s in $statuses) { [Console]::Out.WriteLine("  $($s.Name): $($s.Count)") }
[Console]::Out.WriteLine("Done.")
