# Fix template/generic solutions by marking them as incomplete
# Also mark explicit duplicates

$problemsPath = "$PSScriptRoot\..\data\problems.json"
$indexPath = "$PSScriptRoot\..\data\problems-index.json"

Write-Host "Loading problems.json..."
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json

# Known template solution prefixes (first 100 chars that indicate a template)
$templatePrefixes = @(
    "**Approach:** We solve this using fundamental probability theory.",
    "**Approach:** We use a efficient algorithm.",
    "**Approach:** This brain teaser requires creative reasoning",
    "**Approach:** We apply linear regression and OLS estimation.",
    "**Approach:** We apply matrix algebra.",
    "**Approach:** We solve this using independence and the product rule.",
    "**Approach:** We use a sorting-based approach.",
    "**Approach:** We solve this using linearity of expectation",
    "**Approach:** We analyze this using strategic analysis.",
    "**Approach:** We solve this using Bayes' theorem and conditional probability.",
    "**Approach:** We use a dynamic programming.",
    "**Approach:** We use a hash map for O(1) lookups.",
    "**Approach:** We apply options pricing theory.",
    "**Approach:** We apply stochastic calculus and Ito's lemma.",
    "**Approach:** We use expected value computation.",
    "**Approach:** We use a interval sorting and merging.",
    "**Approach:** We apply quantitative finance theory.",
    "**Approach:** We apply risk-adjusted performance measurement.",
    "**Approach:** We analyze this using optimal betting strategy analysis.",
    "**Approach:** We use a graph traversal (BFS/DFS).",
    "**Approach:** We use a stack/queue-based approach.",
    "**Approach:** We analyze this using time series methods.",
    "**Approach:** We apply combinatorial counting techniques.",
    "**Approach:** We apply eigenvalue decomposition.",
    "**Approach:** We apply risk management and hedging.",
    "**Approach:** We apply statistical inference.",
    "**Approach:** We apply factor model analysis.",
    "**Approach:** We use a sliding window technique.",
    "**Approach:** We use a tree traversal (DFS/BFS).",
    "**Approach:** We apply machine learning theory.",
    "**Approach:** We use a two-pointer technique.",
    "**Approach:** We apply bias-variance analysis.",
    "**Approach:** We apply matrix inversion.",
    "**Approach:** We apply rank-nullity theorem.",
    "**Approach:** We apply Cholesky decomposition.",
    "**Approach:** We apply orthogonal projection.",
    "**Approach:** We use law of iterated expectations.",
    "**Approach:** We apply maximum likelihood estimation.",
    "**Approach:** We use geometric distribution / first-step analysis.",
    "**Approach:** We solve this using Markov chain analysis and transition matrices."
)

# Also check for the generic body pattern that ALL templates share
$genericBodyPatterns = @(
    "1. Parse the input and identify the key data structure. 2. Apply the appropriate algorithmic pattern. 3. Handle edge cas",
    "Identify the relevant distributions, parameters, and estimators.  **Step 2: Mathematical Setup**  Key r",
    "Identify the relevant financial concepts and set up the mathematical model.  **Step 2: Key Formulas",
    "We identify the relevant random variables and their distributions",
    "Identify the players, their strategies, information structure, and payoffs."
)

# Explicit duplicates (say "repeat of problem X" in solution)
$explicitDuplicateIds = @(415, 426, 430, 439)

$templateCount = 0
$dupCount = 0
$alreadyIncomplete = 0
$noSolution = 0

foreach ($p in $problems) {
    # Skip already non-complete
    if ($p.status -eq 'title-only' -or $p.status -eq 'duplicate') {
        continue
    }

    # Handle explicit duplicates
    if ($explicitDuplicateIds -contains $p.id) {
        Write-Host "DUPLICATE: #$($p.id) '$($p.title)' -> marking as duplicate"
        $p.status = 'duplicate'
        $dupCount++
        continue
    }

    # Check if solution exists
    $sol = $p.solution
    if (-not $sol -or $sol.Length -lt 30) {
        if ($p.status -eq 'complete') {
            Write-Host "NO_SOLUTION: #$($p.id) '$($p.title)' -> marking as incomplete"
            $p.status = 'incomplete'
            $noSolution++
        }
        continue
    }

    # Check against template prefixes
    $isTemplate = $false
    foreach ($prefix in $templatePrefixes) {
        if ($sol.StartsWith($prefix)) {
            $isTemplate = $true
            break
        }
    }

    # Also check for generic body patterns
    if (-not $isTemplate) {
        foreach ($pattern in $genericBodyPatterns) {
            if ($sol.Contains($pattern)) {
                # Double check: if the solution is short and generic
                # Some real solutions might reference these phrases but have actual content
                # Template solutions are typically 400-800 chars and entirely generic
                if ($sol.Length -lt 1500) {
                    $isTemplate = $true
                    break
                }
            }
        }
    }

    if ($isTemplate) {
        # Clear the template solution and mark as incomplete
        $p.solution = ""
        $p.status = "incomplete"
        $templateCount++
    }
}

Write-Host ""
Write-Host "========================================="
Write-Host "RESULTS:"
Write-Host "  Template solutions cleared: $templateCount"
Write-Host "  Explicit duplicates marked: $dupCount"
Write-Host "  No-solution marked incomplete: $noSolution"
Write-Host "========================================="

# Count final status distribution
$statuses = @{}
foreach ($p in $problems) {
    $s = $p.status
    if (-not $statuses.ContainsKey($s)) { $statuses[$s] = 0 }
    $statuses[$s]++
}
Write-Host ""
Write-Host "Final status distribution:"
foreach ($entry in ($statuses.GetEnumerator() | Sort-Object Value -Descending)) {
    Write-Host "  $($entry.Key): $($entry.Value)"
}

Write-Host ""
Write-Host "Saving problems.json..."
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8
Write-Host "Done. File size: $((Get-Item $problemsPath).Length / 1KB) KB"
