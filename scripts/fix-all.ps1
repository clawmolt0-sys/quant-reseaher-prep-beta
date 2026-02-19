# Comprehensive quality fix for ALL problems
# Fixes: formatting, tags, types, categories, titles, solutions, duplicates
# Run in one pass over the entire database

$problemsPath = "$PSScriptRoot\..\data\problems.json"
[Console]::Out.WriteLine("Loading problems.json...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
[Console]::Out.WriteLine("  Total: $($problems.Count)")

# Counters
$fixes = @{
    'custom_latex' = 0
    'type_mismatch' = 0
    'should_be_conceptual' = 0
    'should_be_proof' = 0
    'should_be_estimation' = 0
    'empty_tags' = 0
    'bad_title' = 0
    'html_removed' = 0
    'mojibake_cleared' = 0
    'category_fix' = 0
    'difficulty_fix' = 0
    'multi_problem' = 0
    'statement_cleanup' = 0
    'solution_cleanup' = 0
    'duplicate_found' = 0
    'wrong_category' = 0
}

# ============ TITLE FINGERPRINT INDEX for dedup ============
$titleFp = @{}
foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    $fp = ($p.title.ToLower() -replace '[^a-z0-9]', '').Trim()
    if ($fp.Length -gt 8) {
        if (-not $titleFp.ContainsKey($fp)) { $titleFp[$fp] = @() }
        $titleFp[$fp] += $p
    }
}

# ============ KNOWN TAG ASSIGNMENTS BY KEYWORD ============
function Get-AutoTags($title, $stmt, $cat) {
    $text = "$title $stmt".ToLower()
    $tags = @()

    # Probability / Stats
    if ($text -match 'bayes|posterior|prior|likelihood') { $tags += 'bayesian' }
    if ($text -match 'conditional.*prob|given that|P\(.*\|') { $tags += 'conditional-probability' }
    if ($text -match 'expected.*value|E\[|expectation') { $tags += 'expected-value' }
    if ($text -match 'random.*walk') { $tags += 'random-walk' }
    if ($text -match 'markov.*chain|transition.*matrix|stationary.*distribution') { $tags += 'markov-chains' }
    if ($text -match 'normal.*distribution|gaussian|N\(0|standard.*normal') { $tags += 'normal-distribution' }
    if ($text -match 'poisson') { $tags += 'poisson' }
    if ($text -match 'binomial') { $tags += 'binomial' }
    if ($text -match 'exponential.*distribution|memoryless') { $tags += 'exponential' }
    if ($text -match 'uniform.*distribution|uniform\(|U\(0') { $tags += 'uniform' }
    if ($text -match 'central.*limit|CLT') { $tags += 'central-limit-theorem' }
    if ($text -match 'monte.*carlo') { $tags += 'monte-carlo' }
    if ($text -match 'indicator.*variable|indicator.*function') { $tags += 'indicator-variables' }
    if ($text -match 'coupon.*collector') { $tags += 'coupon-collector' }
    if ($text -match 'birthday.*problem|birthday.*paradox') { $tags += 'birthday-problem' }
    if ($text -match 'gambler.*ruin') { $tags += 'gamblers-ruin' }
    if ($text -match 'martingale') { $tags += 'martingales' }

    # Coin/dice
    if ($text -match '\bcoin\b|flip|toss|heads|tails') { $tags += 'coins' }
    if ($text -match '\bdice?\b|die\b|sided.*die|fair.*die') { $tags += 'dice' }
    if ($text -match '\bcard\b|deck|poker|blackjack') { $tags += 'cards' }

    # Finance
    if ($text -match 'black.*scholes|BSM') { $tags += 'black-scholes' }
    if ($text -match 'option.*pric|call.*option|put.*option|european.*option') { $tags += 'options' }
    if ($text -match 'delta.*hedg|gamma.*hedg|greeks') { $tags += 'greeks' }
    if ($text -match 'volatility|implied.*vol|vol.*surface') { $tags += 'volatility' }
    if ($text -match 'brownian.*motion|wiener.*process') { $tags += 'brownian-motion' }
    if ($text -match 'stochastic.*differential|SDE|ito') { $tags += 'stochastic-calculus' }
    if ($text -match 'market.*mak|bid.*ask|spread|order.*book') { $tags += 'market-making' }
    if ($text -match 'sharpe.*ratio') { $tags += 'sharpe-ratio' }
    if ($text -match 'portfolio|mean.*variance|markowitz') { $tags += 'portfolio' }

    # ML / Stats
    if ($text -match 'regression|OLS|least.*squares') { $tags += 'regression' }
    if ($text -match 'PCA|principal.*component') { $tags += 'pca' }
    if ($text -match 'hypothesis.*test|p.*value|significance') { $tags += 'hypothesis-testing' }
    if ($text -match 'maximum.*likelihood|MLE') { $tags += 'mle' }
    if ($text -match 'gradient.*descent') { $tags += 'optimization' }
    if ($text -match 'neural.*net|deep.*learn') { $tags += 'neural-networks' }
    if ($text -match 'cross.*valid') { $tags += 'cross-validation' }
    if ($text -match 'bias.*variance|overfitting') { $tags += 'bias-variance' }

    # Coding
    if ($text -match 'dynamic.*program|DP|memoiz') { $tags += 'dynamic-programming' }
    if ($text -match 'binary.*search') { $tags += 'binary-search' }
    if ($text -match 'linked.*list') { $tags += 'linked-list' }
    if ($text -match 'hash.*map|hash.*table|dictionary') { $tags += 'hash-table' }
    if ($text -match 'tree|BST|binary.*tree') { $tags += 'trees' }
    if ($text -match 'graph.*algorithm|BFS|DFS|shortest.*path|dijkstra') { $tags += 'graphs' }
    if ($text -match 'sort|merge.*sort|quick.*sort|heap.*sort') { $tags += 'sorting' }
    if ($text -match 'system.*design') { $tags += 'system-design' }

    # Math
    if ($text -match 'eigenvalue|eigenvector') { $tags += 'eigenvalues' }
    if ($text -match 'matrix|matrices|determinant') { $tags += 'matrices' }
    if ($text -match 'integral|integrat|calculus') { $tags += 'calculus' }
    if ($text -match 'combinat|permutation|combination|choose|C\(n') { $tags += 'combinatorics' }
    if ($text -match 'recurren|recurrence') { $tags += 'recurrence-relations' }

    return @($tags | Sort-Object -Unique)
}

# ============ MAIN LOOP ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Processing all problems...")

foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }

    $stmt = if ($p.statement) { $p.statement } else { '' }
    $sol = if ($p.solution) { $p.solution } else { '' }
    $cat = $p.category
    $type = $p.type
    $title = $p.title

    # ---- 1. Custom LaTeX macros ----
    $macroPattern = '\\(unif|ev|prob|binomial|expected|var|cov|indicator|floor|ceil)\{'
    if ($stmt -match $macroPattern -or $sol -match $macroPattern) {
        $replacements = @(
            @('\\unif\{([^}]*)\}\{([^}]*)\}', 'U($1, $2)'),
            @('\\ev\{([^}]*)\}', 'E[$1]'),
            @('\\expected\{([^}]*)\}', 'E[$1]'),
            @('\\prob\{([^}]*)\}', 'P($1)'),
            @('\\var\{([^}]*)\}', '\text{Var}($1)'),
            @('\\cov\{([^}]*)\}\{([^}]*)\}', '\text{Cov}($1, $2)'),
            @('\\binomial\{([^}]*)\}\{([^}]*)\}', '\text{Bin}($1, $2)'),
            @('\\indicator\{([^}]*)\}', '\mathbf{1}_{$1}'),
            @('\\floor\{([^}]*)\}', '\lfloor $1 \rfloor'),
            @('\\ceil\{([^}]*)\}', '\lceil $1 \rceil')
        )
        foreach ($r in $replacements) {
            if ($stmt -match $r[0]) { $p.statement = $p.statement -replace $r[0], $r[1]; $stmt = $p.statement }
            if ($sol -match $r[0]) { $p.solution = $p.solution -replace $r[0], $r[1]; $sol = $p.solution }
        }
        $fixes['custom_latex']++
    }

    # ---- 2. HTML tags ----
    if ($stmt -match '<[a-zA-Z][^>]*>' -or $sol -match '<[a-zA-Z][^>]*>') {
        # Keep code blocks but remove other HTML
        $p.statement = $p.statement -replace '<(?!code|/code|pre|/pre)[^>]+>', ''
        $p.solution = $p.solution -replace '<(?!code|/code|pre|/pre)[^>]+>', ''
        $stmt = $p.statement; $sol = $p.solution
        $fixes['html_removed']++
    }

    # ---- 3. Type mismatches ----
    # Coding category must have coding type
    if ($cat -eq 'coding' -and $type -ne 'coding') {
        $p.type = 'coding'
        $fixes['type_mismatch']++
    }
    # Brain-teaser category should have brain-teaser type
    if ($cat -eq 'brain-teaser' -and $type -notin @('brain-teaser', 'estimation', 'strategy')) {
        $p.type = 'brain-teaser'
        $fixes['type_mismatch']++
    }

    # ---- 4. Type should be conceptual/proof/estimation ----
    if ($type -eq 'calculation') {
        if ($stmt -match '(?i)^(explain|describe|discuss|list|what are|compare|contrast|define|interpret|why does|why is|what is the difference)') {
            $p.type = 'conceptual'
            $fixes['should_be_conceptual']++
        } elseif ($stmt -match '(?i)^(show that|prove|demonstrate that|verify that)') {
            $p.type = 'proof'
            $fixes['should_be_proof']++
        } elseif ($stmt -match '(?i)^(estimate|how many|approximately|order of magnitude|fermi)') {
            $p.type = 'estimation'
            $fixes['should_be_estimation']++
        }
    }

    # ---- 5. Category fixes ----
    # Problems in wrong category
    if ($cat -eq 'statistics' -and $stmt -match '(?i)E\[max|E\[min|expected.*max|expected.*min|expected.*number') {
        if ($stmt -notmatch '(?i)hypothesis|confidence|p.value|test.*statistic') {
            $p.category = 'expectation'
            $fixes['wrong_category']++
        }
    }
    if ($cat -eq 'probability' -and $stmt -match '(?i)code|implement|function|algorithm|array|string|program|leetcode|O\(n\)') {
        if ($stmt -match '(?i)write.*code|implement.*function|design.*class|given.*array') {
            $p.category = 'coding'
            $p.type = 'coding'
            $fixes['wrong_category']++
        }
    }
    if ($cat -eq 'linear-algebra' -and $stmt -match '(?i)P\(|probability|conditional|given that|expected') {
        if ($stmt -notmatch '(?i)matrix|eigen|vector|determinant|rank') {
            $p.category = 'probability'
            $fixes['wrong_category']++
        }
    }

    # ---- 6. Auto-tag empty problems ----
    $existingTags = @()
    if ($p.tags) { $existingTags = @($p.tags) }
    if ($existingTags.Count -eq 0 -or ($existingTags.Count -eq 1 -and $existingTags[0] -eq '')) {
        $autoTags = Get-AutoTags $title $stmt $cat
        if ($autoTags.Count -gt 0) {
            $p.tags = $autoTags
            $fixes['empty_tags']++
        }
    }

    # ---- 7. Title cleanup ----
    # Remove "Probability: " or "Coding: " prefix from titles (redundant with category)
    if ($title -match '^(Probability|Coding|Statistics|Finance|Math|Algorithm)[:\s]+(.+)') {
        $newTitle = $Matches[2].Trim()
        if ($newTitle.Length -gt 10) {
            $p.title = $newTitle
            $fixes['bad_title']++
        }
    }
    # Remove "(Coding Problem)" suffix
    if ($title -match '\s*\(Coding Problem\)\s*$') {
        $p.title = $title -replace '\s*\(Coding Problem\)\s*$', ''
        $fixes['bad_title']++
    }
    # Fix titles that are just the first sentence of the problem
    if ($title.Length -gt 100 -and $title -match '^(.{30,80}?)\s') {
        # Only shorten if title is way too long
        $words = $title -split '\s+'
        if ($words.Count -gt 15) {
            $shortened = ($words[0..9] -join ' ') + '...'
            # Don't actually shorten - just flag. Many long titles are fine.
        }
    }
    # Clean up "Problem N:" prefix in titles
    if ($title -match '^Problem\s+\d+[:\s]+(.+)') {
        $p.title = $Matches[1].Trim()
        $fixes['bad_title']++
    }

    # ---- 8. Statement cleanup ----
    # Remove leading/trailing whitespace
    if ($stmt -match '^\s+' -or $stmt -match '\s+$') {
        $p.statement = $stmt.Trim()
        $fixes['statement_cleanup']++
    }
    # Fix double newlines → single
    if ($stmt -match '\n{3,}') {
        $p.statement = $p.statement -replace '\n{3,}', "`n`n"
        $fixes['statement_cleanup']++
    }

    # ---- 9. Solution cleanup ----
    if ($sol.Length -gt 0) {
        # Remove leading "**Approach:**" if it's followed by the actual approach then "**Solution:**"
        # (These are template solutions that are OK but redundant headers)

        # Fix broken LaTeX: "$ = " at start of line (missing variable name)
        if ($sol -match '(?m)^\$\s*=\s') {
            $p.solution = $p.solution -replace '(?m)^\$\s*=\s', '$$f = '
            $fixes['solution_cleanup']++
        }
    }

    # ---- 10. Difficulty sanity check ----
    if ($p.difficulty -notin @('easy', 'medium', 'hard')) {
        $p.difficulty = 'medium'
        $fixes['difficulty_fix']++
    }

    # ---- 11. Mojibake detection ----
    # Severe mojibake patterns (like in ID 129)
    if ($sol -match 'A\?\?[sTz]|A\+\?T|A,A\?|\.Groups\[1\]') {
        $p.solution = ''
        $p.status = 'incomplete'
        $fixes['mojibake_cleared']++
        [Console]::Out.WriteLine("  MOJIBAKE: ID $($p.id) - $($p.title)")
    }
}

# ============ DEDUP PASS: catch remaining exact title dups ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Checking for remaining exact title duplicates...")
$titleFp2 = @{}
foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    $fp = ($p.title.ToLower() -replace '[^a-z0-9]', '').Trim()
    if ($fp.Length -le 10) { continue }
    if ($titleFp2.ContainsKey($fp)) {
        $existing = $titleFp2[$fp]
        # Keep the one with better solution
        $q1 = if ($existing.solution) { $existing.solution.Length } else { 0 }
        $q2 = if ($p.solution) { $p.solution.Length } else { 0 }
        if ($q2 -gt $q1) {
            # Merge companies from existing into new keeper
            if ($existing.companies) {
                foreach ($c in $existing.companies) {
                    if ($c -notin @($p.companies)) { $p.companies = @($p.companies) + $c }
                }
            }
            $existing.status = 'duplicate'
            $titleFp2[$fp] = $p
        } else {
            if ($p.companies) {
                foreach ($c in $p.companies) {
                    if ($c -notin @($existing.companies)) { $existing.companies = @($existing.companies) + $c }
                }
            }
            $p.status = 'duplicate'
        }
        $fixes['duplicate_found']++
    } else {
        $titleFp2[$fp] = $p
    }
}

# ============ REPORT ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("COMPREHENSIVE FIX RESULTS:")
foreach ($entry in ($fixes.GetEnumerator() | Sort-Object Value -Descending)) {
    if ($entry.Value -gt 0) {
        [Console]::Out.WriteLine("  $($entry.Key): $($entry.Value)")
    }
}
$totalFixes = ($fixes.Values | Measure-Object -Sum).Sum
[Console]::Out.WriteLine("  TOTAL: $totalFixes")
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
