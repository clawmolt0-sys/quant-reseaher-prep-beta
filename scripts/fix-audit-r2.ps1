# Fix Audit Round 2 — tackles remaining 1,270 issues
# Focuses on: unmatched dollars, escaped dollars, title improvements, UTF8, duplicates, tags
#
# Issues to fix:
#   BROKEN_TITLE_FRAGMENT: 148
#   BROKEN_TITLE_TRAILING: 4
#   TITLE_IS_STMT: 703
#   UNMATCHED_DOLLAR_SOL: 90
#   UNMATCHED_DOLLAR_STMT: 64
#   NO_TAGS_COMPLETE: 185
#   UTF8_GARBLED: 44
#   RAW_LATEX_MACRO: 2
#   DUPLICATE_TITLE: 4
#   VERY_SHORT_STMT: 22
#   EMPTY_STMT_COMPLETE: 2
#   TITLE_TOO_LONG: 2

$problemsPath = "$PSScriptRoot\..\data\problems.json"
[Console]::Out.WriteLine("Loading problems.json...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
$active = @($problems | Where-Object { $_.status -ne 'duplicate' })
[Console]::Out.WriteLine("  Total: $($problems.Count), Active: $($active.Count)")

$byId = @{}
foreach ($p in $problems) { $byId[$p.id] = $p }

$counters = @{
    dollar_stmt_fixed = 0
    dollar_sol_fixed = 0
    escaped_dollar_fixed = 0
    title_fragment_fixed = 0
    title_trailing_fixed = 0
    title_is_stmt_fixed = 0
    title_too_long_fixed = 0
    tags_added = 0
    utf8_fixed = 0
    latex_macro_fixed = 0
    duplicate_fixed = 0
    very_short_cleared = 0
    empty_stmt_fixed = 0
    type_fixed = 0
    title_case_fixed = 0
}

# ============================================================
# HELPER: Generate title from statement
# ============================================================
$stopWords = @('the','and','for','that','this','with','from','have','been','will','would','could','should','which','their','there','they','about','after','before','being','between','both','during','each','than','then','these','those','through','under','very','what','when','where','while','into','most','much','must','only','other','over','same','some','such','also','just','like','make','many','more','need','find','given','know','take','want','does','using','used','consider','following','problem','question','answer','solution','solve','determine','calculate','compute','show','prove','explain','suppose','assume','let','define','note','hint','example','task','context','asked','round','interview','write','implement','return','input','output','function','class','method','are','was','were','has','had','its','you','your','can','not','how','all','one','two','three','four','five','first','second','new','way','may','part','get','got','say','set','try','too','use','her','him','his','she','see','now','old','big','come','made','think','every','give','well','our','back')

$smallWords = @('a','an','the','and','or','but','nor','for','yet','so','in','on','at','to','by','of','as','is','if','up','it','be','do','no','we','he','vs')

function Title-Case($text) {
    $words = @($text -split '\s+')
    $result = @()
    for ($i = 0; $i -lt $words.Count; $i++) {
        $w = $words[$i]
        if ($w.Length -eq 0) { continue }
        # Always capitalize first and last word
        if ($i -eq 0 -or $i -eq $words.Count - 1 -or $w.ToLower() -notin $smallWords) {
            $result += $w.Substring(0,1).ToUpper() + $w.Substring(1)
        } else {
            $result += $w.ToLower()
        }
    }
    return ($result -join ' ')
}

function Generate-Title($stmt, $category) {
    if (-not $stmt -or $stmt.Length -lt 15) { return $null }

    # Strip LaTeX for analysis
    $clean = $stmt -replace '\$\$[^$]*\$\$', '' -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+\{[^}]*\}', '' -replace '\\[a-zA-Z]+', ''
    $clean = $clean -replace '`', '' -replace '\\\$', '$'
    $clean = $clean -replace '[^a-zA-Z0-9\s,.\-]', ' ' -replace '\s+', ' '
    $clean = $clean.Trim()

    if ($clean.Length -lt 10) { return $null }

    # Try first meaningful sentence
    $firstSent = ($clean -split '[.?!\n]')[0].Trim()
    # Remove leading (a), (1), etc.
    $firstSent = $firstSent -replace '^\([a-z0-9]\)\s*', ''
    # Remove leading "Suppose ", "Given ", "Consider ", "Let " for shorter titles
    $core = $firstSent -replace '^(Suppose|Given|Consider|Assume|Let|Say)\s+(that\s+)?', ''

    if ($core.Length -gt 10 -and $core.Length -le 65) {
        $core = $core -replace '\s+(and|or|the|a|an|is|are|in|of|to|for|with|that|which|from|by|at|on|as|if|but|not|into|than|its)\s*$', ''
        $core = $core.Trim(' ,')
        if ($core.Length -gt 10) {
            return Title-Case $core
        }
    }

    # Use first sentence if short enough
    if ($firstSent.Length -gt 10 -and $firstSent.Length -le 65) {
        $firstSent = $firstSent -replace '\s+(and|or|the|a|an|is|are|in|of|to|for|with|that|which|from|by|at|on|as|if|but|not|into|than|its)\s*$', ''
        $firstSent = $firstSent.Trim(' ,')
        if ($firstSent.Length -gt 10) {
            return Title-Case $firstSent
        }
    }

    # Fallback: extract key nouns
    $words = @($clean.Substring(0, [math]::Min(120, $clean.Length)) -split '\s+' | Where-Object { $_.Length -gt 3 -and $_.ToLower() -notin $stopWords } | Select-Object -First 6)
    if ($words.Count -ge 2) {
        $titled = @()
        foreach ($w in $words) { $titled += $w.Substring(0,1).ToUpper() + $w.Substring(1).ToLower() }
        return ($titled -join ' ')
    }

    return $null
}

function Get-AutoTags($title, $stmt, $cat) {
    $text = "$title $stmt".ToLower()
    $tags = @()
    if ($text -match 'bayes|posterior|prior|likelihood') { $tags += 'bayesian' }
    if ($text -match 'conditional.*prob|given that') { $tags += 'conditional-probability' }
    if ($text -match 'expected.*value|E\[|expectation') { $tags += 'expected-value' }
    if ($text -match 'random.*walk') { $tags += 'random-walk' }
    if ($text -match 'markov.*chain|transition.*matrix') { $tags += 'markov-chains' }
    if ($text -match 'normal.*distribution|gaussian|standard.*normal') { $tags += 'normal-distribution' }
    if ($text -match 'poisson') { $tags += 'poisson' }
    if ($text -match 'binomial') { $tags += 'binomial' }
    if ($text -match 'uniform.*distribution') { $tags += 'uniform' }
    if ($text -match 'monte.*carlo') { $tags += 'monte-carlo' }
    if ($text -match '\bcoin\b|flip|toss|heads|tails') { $tags += 'coins' }
    if ($text -match '\bdice?\b|die\b') { $tags += 'dice' }
    if ($text -match '\bcard\b|deck|poker') { $tags += 'cards' }
    if ($text -match 'black.*scholes') { $tags += 'black-scholes' }
    if ($text -match 'option.*pric|call.*option|put.*option') { $tags += 'options' }
    if ($text -match 'volatility|implied.*vol') { $tags += 'volatility' }
    if ($text -match 'brownian.*motion|wiener') { $tags += 'brownian-motion' }
    if ($text -match 'stochastic.*differential|SDE|ito') { $tags += 'stochastic-calculus' }
    if ($text -match 'regression|OLS|least.*squares') { $tags += 'regression' }
    if ($text -match 'PCA|principal.*component') { $tags += 'pca' }
    if ($text -match 'hypothesis.*test|p.value|significance') { $tags += 'hypothesis-testing' }
    if ($text -match 'dynamic.*program|DP|memoiz') { $tags += 'dynamic-programming' }
    if ($text -match 'binary.*search') { $tags += 'binary-search' }
    if ($text -match 'matrix|matrices|determinant') { $tags += 'matrices' }
    if ($text -match 'eigenvalue|eigenvector') { $tags += 'eigenvalues' }
    if ($text -match 'integral|integrat') { $tags += 'calculus' }
    if ($text -match 'combinat|permutation|choose') { $tags += 'combinatorics' }
    if ($text -match 'martingale') { $tags += 'martingales' }
    if ($text -match 'coupon.*collector') { $tags += 'coupon-collector' }
    if ($text -match 'birthday') { $tags += 'birthday-problem' }
    if ($text -match 'gambler.*ruin') { $tags += 'gamblers-ruin' }
    if ($text -match 'urn|marble|ball.*box|box.*ball') { $tags += 'urn-model' }
    if ($text -match 'central.*limit|CLT') { $tags += 'central-limit-theorem' }
    if ($text -match 'variance|standard deviation') { $tags += 'variance' }
    if ($text -match 'covariance|correlation') { $tags += 'covariance' }
    if ($text -match 'exponential.*distribut') { $tags += 'exponential-distribution' }
    if ($text -match 'geometric.*distribut|geometric.*random') { $tags += 'geometric-distribution' }
    if ($text -match 'moment.*generat|MGF|characteristic.*function') { $tags += 'moment-generating-function' }
    if ($text -match 'maximum.*likelihood|MLE') { $tags += 'maximum-likelihood' }
    if ($text -match 'confidence.*interval') { $tags += 'confidence-interval' }
    if ($text -match 'linear.*regress') { $tags += 'linear-regression' }
    if ($text -match 'time.*series|ARMA|GARCH|autocorrelation') { $tags += 'time-series' }
    if ($text -match 'portfolio|sharpe|efficient.*frontier') { $tags += 'portfolio' }
    if ($text -match 'greeks?|delta|gamma|theta|vega|rho') { $tags += 'greeks' }
    if ($text -match 'yield.*curve|term.*structure') { $tags += 'yield-curve' }
    if ($text -match 'sorting|merge.*sort|quick.*sort|heap.*sort') { $tags += 'sorting' }
    if ($text -match 'graph|BFS|DFS|shortest.*path|dijkstra') { $tags += 'graphs' }
    if ($text -match 'tree|BST|binary.*tree|trie') { $tags += 'trees' }
    if ($text -match 'hash.*map|hash.*table|dictionary') { $tags += 'hash-tables' }
    if ($text -match 'linked.*list') { $tags += 'linked-list' }
    if ($text -match 'recursion|recursive') { $tags += 'recursion' }
    if ($text -match 'string|substring|palindrome|anagram') { $tags += 'strings' }
    return @($tags | Sort-Object -Unique)
}

# ============================================================
# PASS 1: Fix unmatched dollar signs in statements
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 1: Fix unmatched dollar signs ===")

function Fix-Dollars($text) {
    if (-not $text -or $text.Length -eq 0) { return $text }

    $changed = $false

    # Fix 1: Bare currency like $100, $120, $80 NOT inside math mode
    # Pattern: $NNN followed by non-math chars (space, period, comma, etc.)
    # Replace $NNN with \$NNN (escaped dollar)
    # But be careful not to touch $X_1$ or $\frac{1}{2}$ etc.
    # Bare currency: $ followed by digits, optionally comma/period/digits, then word boundary
    $result = $text -replace '(?<!\$)\$(\d[\d,]*\.?\d*)([\s,.\)\]!?;:\-]|$)', '\$$1$2'

    # Fix 2: \$NNN$ pattern — the trailing $ is a stray math delimiter
    # e.g., \$100$ should be \$100 (the $ after 100 is not math)
    $result = $result -replace '\\\$(\d[\d,]*\.?\d*)\$', '\$$1'

    # Fix 3: $[...] missing the E — should be $E[...]$
    # Common pattern: $[\text{...}] should be $E[\text{...}]$
    $result = $result -replace '\$\[([^\]]*)\]', '$E[$1]'

    if ($result -ne $text) { $changed = $true }
    return $result
}

foreach ($p in $active) {
    $stmt = if ($p.statement) { $p.statement } else { '' }
    $sol = if ($p.solution) { $p.solution } else { '' }

    # Count dollars to check for odd count
    $stmtDollars = ($stmt -split '\$').Count - 1
    $solDollars = ($sol -split '\$').Count - 1

    if ($stmtDollars -gt 0 -and $stmtDollars % 2 -ne 0) {
        $fixed = Fix-Dollars $stmt
        if ($fixed -ne $stmt) {
            $p.statement = $fixed
            $counters['dollar_stmt_fixed']++
        }
    }
    if ($solDollars -gt 0 -and $solDollars % 2 -ne 0) {
        $fixed = Fix-Dollars $sol
        if ($fixed -ne $sol) {
            $p.solution = $fixed
            $counters['dollar_sol_fixed']++
        }
    }
}

[Console]::Out.WriteLine("  Dollar signs fixed in statements: $($counters['dollar_stmt_fixed'])")
[Console]::Out.WriteLine("  Dollar signs fixed in solutions: $($counters['dollar_sol_fixed'])")

# ============================================================
# PASS 2: Fix escaped dollar signs outside math mode
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 2: Fix escaped dollar signs ===")

foreach ($p in $active) {
    $stmt = if ($p.statement) { $p.statement } else { '' }
    $sol = if ($p.solution) { $p.solution } else { '' }
    $changed = $false

    # Fix \$NNN outside of math mode — these show as \$1 instead of $1
    # Pattern: \$ followed by number, NOT preceded by $ (not inside math)
    # We want to replace standalone \$NNN with $NNN (proper currency display)
    # But ONLY when it's not inside $...$
    # Simple heuristic: if the text has \$NNN and it's NOT inside $...$,
    # wrap it in math mode: $\$NNN$
    # Actually, the problem is \$1 shows literally — let's just ensure they're in math mode

    # Check for \$NNN patterns that might be outside math mode
    if ($stmt -match '(?<!\$)\\\$\d' -or $sol -match '(?<!\$)\\\$\d') {
        # More targeted: find \$NUMBER that are standalone (not already inside $...$)
        # We can't easily parse math mode in regex, so let's fix the most common case:
        # Line starts with or has whitespace before \$NNN
        if ($stmt -match '(^|[\s(,])\\\$(\d)') {
            # Wrap bare \$NNN in math mode
            $p.statement = $p.statement -replace '(^|[\s(,])\\\$(\d[\d,.]*)', '$1$\$$2$'
            $changed = $true
        }
        if ($sol -match '(^|[\s(,])\\\$(\d)') {
            $p.solution = $p.solution -replace '(^|[\s(,])\\\$(\d[\d,.]*)', '$1$\$$2$'
            $changed = $true
        }
        if ($changed) { $counters['escaped_dollar_fixed']++ }
    }
}

[Console]::Out.WriteLine("  Escaped dollars fixed: $($counters['escaped_dollar_fixed'])")

# ============================================================
# PASS 3: Fix broken fragment titles
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 3: Fix broken fragment titles ===")

foreach ($p in $active) {
    $title = $p.title
    $stmt = if ($p.statement) { $p.statement } else { '' }

    $needsFix = $false

    # Fragment title (starts with lowercase preposition/article/conjunction but capitalized)
    if ($title -match '^(of |the |and |is |are |to |in |for |a |an |that |with |from |by |at |on |or |as |it |if |be |do |so |but |not |we |you |he |she )') {
        $needsFix = $true
    }
    # Trailing preposition (truncated)
    if ($title -match '\s(the|and|or|of|to|in|for|with|a|an|is|are|that|which|from|by|at|on|as|if|but|not|into|than|its|this|these|those|when|where|how|what|who)\s*$') {
        $needsFix = $true
    }

    if ($needsFix) {
        if ($stmt.Length -gt 20) {
            $newTitle = Generate-Title $stmt $p.category
            if ($newTitle -and $newTitle.Length -gt 8 -and $newTitle.Length -le 70) {
                $p.title = $newTitle
                $counters['title_fragment_fixed']++
            } else {
                # Can't generate better title from statement, try to fix current title
                # Remove leading articles/prepositions
                $cleaned = $title -replace '^(Of |The |And |Is |Are |To |In |For |A |An |That |With |From |By |At |On |Or |As |It |If |Be |Do |So |But |Not |We |You |He |She )+', ''
                # Remove trailing prepositions
                $cleaned = $cleaned -replace '\s+(the|and|or|of|to|in|for|with|a|an|is|are|that|which|from|by|at|on|as|if|but|not|into|than|its)\s*$', ''
                $cleaned = $cleaned.Trim(' ,')
                if ($cleaned.Length -gt 8) {
                    $p.title = Title-Case $cleaned
                    $counters['title_fragment_fixed']++
                }
            }
        } else {
            # No statement to work with — fix title directly
            $cleaned = $title -replace '^(Of |The |And |Is |Are |To |In |For |A |An |That |With |From |By |At |On |Or |As |It |If |Be |Do |So |But |Not |We |You |He |She )+', ''
            $cleaned = $cleaned -replace '\s+(the|and|or|of|to|in|for|with|a|an|is|are|that|which|from|by|at|on|as|if|but|not|into|than|its)\s*$', ''
            $cleaned = $cleaned.Trim(' ,')
            if ($cleaned.Length -gt 8) {
                $p.title = Title-Case $cleaned
                $counters['title_fragment_fixed']++
            }
        }
    }
}

[Console]::Out.WriteLine("  Fragment/trailing titles fixed: $($counters['title_fragment_fixed'])")

# ============================================================
# PASS 4: Fix title-is-statement (long titles that duplicate statement)
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 4: Fix title-is-statement duplicates ===")

foreach ($p in $active) {
    $title = $p.title
    $stmt = if ($p.statement) { $p.statement } else { '' }

    if ($title.Length -gt 50 -and $stmt.Length -gt 30) {
        $titleNorm = $title.ToLower() -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
        $stmtFirst = ($stmt -split '\n')[0].Trim()
        $stmtNorm = $stmtFirst.ToLower() -replace '[^a-z0-9\s]', '' -replace '\s+', ' '

        if ($stmtNorm.Length -gt 20 -and $titleNorm.Length -gt 20) {
            $checkLen = [math]::Min(25, [math]::Min($titleNorm.Length, $stmtNorm.Length))
            if ($titleNorm.Substring(0, $checkLen) -eq $stmtNorm.Substring(0, $checkLen)) {
                $newTitle = Generate-Title $stmt $p.category
                if ($newTitle -and $newTitle.Length -gt 8 -and $newTitle.Length -le 70 -and $newTitle.Length -lt $title.Length) {
                    $p.title = $newTitle
                    $counters['title_is_stmt_fixed']++
                }
            }
        }
    }
}

[Console]::Out.WriteLine("  Title-is-stmt fixed: $($counters['title_is_stmt_fixed'])")

# ============================================================
# PASS 5: Fix title casing (ensure proper Title Case)
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 5: Fix title casing ===")

foreach ($p in $active) {
    $title = $p.title
    if (-not $title -or $title.Length -lt 5) { continue }

    # Check if title is all lowercase or starts lowercase
    if ($title[0] -cmatch '[a-z]') {
        $p.title = Title-Case $title
        $counters['title_case_fixed']++
    }
    # Check for "A Discuss" pattern (garbled from "(a)")
    elseif ($title -match '^A [A-Z][a-z]+ [A-Z]' -and $title -match '^A (Discuss|Describe|Explain|Compare|Analyze|Calculate|Define|Evaluate|Implement)') {
        # Remove the leading "A " which came from "(a)" prefix
        $p.title = $title.Substring(2)
        $counters['title_case_fixed']++
    }
}

[Console]::Out.WriteLine("  Title casing fixed: $($counters['title_case_fixed'])")

# ============================================================
# PASS 6: Fix UTF8 garbled text
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 6: Fix UTF8 garbled text ===")

foreach ($p in $active) {
    $stmt = if ($p.statement) { $p.statement } else { '' }
    $sol = if ($p.solution) { $p.solution } else { '' }

    $hasGarble = $false
    if ($stmt -match '[\xC3][\x80-\xBF]') { $hasGarble = $true }
    if ($sol -match '[\xC3][\x80-\xBF]') { $hasGarble = $true }

    if ($hasGarble) {
        # Common UTF8 double-encoding fixes
        $replacements = @(
            @([char]0xC3 + [char]0xA9, [char]0xE9),  # e-acute
            @([char]0xC3 + [char]0xA8, [char]0xE8),  # e-grave
            @([char]0xC3 + [char]0xA0, [char]0xE0),  # a-grave
            @([char]0xC3 + [char]0xA2, [char]0xE2),  # a-circumflex
            @([char]0xC3 + [char]0xB4, [char]0xF4),  # o-circumflex
            @([char]0xC3 + [char]0xBC, [char]0xFC),  # u-umlaut
            @([char]0xC3 + [char]0xB6, [char]0xF6),  # o-umlaut
            @([char]0xC3 + [char]0xA4, [char]0xE4),  # a-umlaut
            @([char]0xC3 + [char]0xAD, [char]0xED),  # i-acute
            @([char]0xC3 + [char]0xB1, [char]0xF1),  # n-tilde
            @([char]0xC3 + [char]0x97, [char]0xD7)   # multiplication sign
        )

        $changed = $false
        foreach ($r in $replacements) {
            if ($p.statement -and $p.statement.Contains($r[0])) {
                $p.statement = $p.statement.Replace($r[0], [string]$r[1])
                $changed = $true
            }
            if ($p.solution -and $p.solution.Contains($r[0])) {
                $p.solution = $p.solution.Replace($r[0], [string]$r[1])
                $changed = $true
            }
        }

        # For heavily garbled text (mojibake), check if it's unsalvageable
        if ($sol -match 'A\?\?[sTz]|A\+\?T' -or $sol -match '([\xC3][\x80-\xBF].*){10}') {
            # Solution is severely garbled — clear it and mark incomplete
            if ($sol.Length -gt 0) {
                # Check if more than 20% of solution is garbled characters
                $garbleCount = ([regex]::Matches($sol, '[\xC3][\x80-\xBF]')).Count
                $ratio = $garbleCount / [math]::Max(1, $sol.Length)
                if ($garbleCount -gt 20) {
                    # Too garbled to fix — clear and mark incomplete
                    $p.solution = ''
                    $p.status = 'incomplete'
                    $changed = $true
                }
            }
        }

        if ($changed) { $counters['utf8_fixed']++ }
    }
}

[Console]::Out.WriteLine("  UTF8 issues fixed: $($counters['utf8_fixed'])")

# ============================================================
# PASS 7: Fix remaining raw LaTeX macros
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 7: Fix raw LaTeX macros ===")

$macroIds = @(2185, 2210)
foreach ($id in $macroIds) {
    if ($byId.ContainsKey($id)) {
        $p = $byId[$id]
        $replacements = @(
            @('\\cov\{([^}]*)\}\{([^}]*)\}', '\text{Cov}($1, $2)'),
            @('\\cov\{([^}]*)\}', '\text{Cov}($1)'),
            @('\\corr\{([^}]*)\}\{([^}]*)\}', '\text{Corr}($1, $2)'),
            @('\\var\{([^}]*)\}', '\text{Var}($1)'),
            @('\\ev\{([^}]*)\}', 'E[$1]'),
            @('\\prob\{([^}]*)\}', 'P($1)')
        )
        foreach ($r in $replacements) {
            if ($p.statement) { $p.statement = $p.statement -replace $r[0], $r[1] }
            if ($p.solution) { $p.solution = $p.solution -replace $r[0], $r[1] }
        }
        $counters['latex_macro_fixed']++
    }
}

[Console]::Out.WriteLine("  LaTeX macros fixed: $($counters['latex_macro_fixed'])")

# ============================================================
# PASS 8: Fix duplicate titles
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 8: Fix duplicate titles ===")

# ID 3182 is dup of 303
if ($byId.ContainsKey(3182) -and $byId.ContainsKey(303)) {
    $p1 = $byId[3182]; $p2 = $byId[303]
    # Keep the one with better content
    if ($p2.solution -and $p2.solution.Length -gt 50) {
        # 303 has solution, merge companies from 3182 into 303
        if ($p1.companies) {
            foreach ($c in $p1.companies) {
                if ($c -notin @($p2.companies)) { $p2.companies = @($p2.companies) + $c }
            }
        }
        $p1.status = 'duplicate'
        $counters['duplicate_fixed']++
    }
}

# Check 3681 vs 3661, 3987 vs 3974, 4024 vs 3860
$dupPairs = @(
    @(3681, 3661),
    @(3987, 3974),
    @(4024, 3860)
)
foreach ($pair in $dupPairs) {
    $id1 = $pair[0]; $id2 = $pair[1]
    if ($byId.ContainsKey($id1) -and $byId.ContainsKey($id2)) {
        $p1 = $byId[$id1]; $p2 = $byId[$id2]
        if ($p1.status -ne 'duplicate' -and $p2.status -ne 'duplicate') {
            # Keep the earlier one (lower ID), mark later as duplicate
            if ($p1.companies) {
                foreach ($c in $p1.companies) {
                    if ($c -notin @($p2.companies)) { $p2.companies = @($p2.companies) + $c }
                }
            }
            if ($p1.tags) {
                foreach ($t in $p1.tags) {
                    if ($t -and $t -notin @($p2.tags)) { $p2.tags = @($p2.tags) + $t }
                }
            }
            # If p1 has better solution, copy it to p2
            $sol1 = if ($p1.solution) { $p1.solution.Length } else { 0 }
            $sol2 = if ($p2.solution) { $p2.solution.Length } else { 0 }
            if ($sol1 -gt $sol2) {
                $p2.solution = $p1.solution
            }
            $p1.status = 'duplicate'
            $counters['duplicate_fixed']++
        }
    }
}

[Console]::Out.WriteLine("  Duplicates fixed: $($counters['duplicate_fixed'])")

# ============================================================
# PASS 9: Fix missing tags (complete problems with no tags)
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 9: Auto-tag complete problems with no tags ===")

foreach ($p in $active) {
    if ($p.status -ne 'complete') { continue }

    $hasTags = $false
    if ($p.tags) {
        $validTags = @($p.tags | Where-Object { $_ -and $_.Length -gt 0 })
        if ($validTags.Count -gt 0) { $hasTags = $true }
    }

    if (-not $hasTags) {
        $stmt = if ($p.statement) { $p.statement } else { '' }
        $autoTags = Get-AutoTags $p.title $stmt $p.category
        if ($autoTags.Count -gt 0) {
            $p.tags = $autoTags
            $counters['tags_added']++
        } else {
            # Fallback: add category-based tag
            $catTag = $p.category
            if ($catTag) {
                $p.tags = @($catTag)
                $counters['tags_added']++
            }
        }
    }
}

[Console]::Out.WriteLine("  Problems auto-tagged: $($counters['tags_added'])")

# ============================================================
# PASS 10: Fix empty stmt complete + very short stmts
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 10: Fix empty/short statements ===")

foreach ($p in $active) {
    $stmt = if ($p.statement) { $p.statement } else { '' }

    # Complete problems with no statement
    if ($p.status -eq 'complete' -and $stmt.Length -eq 0) {
        if (-not $p.solution -or $p.solution.Length -lt 50) {
            $p.status = 'incomplete'
            $counters['empty_stmt_fixed']++
        }
    }

    # Very short statements that are fragments
    if ($stmt.Length -gt 0 -and $stmt.Length -lt 30 -and $stmt -notmatch '\$') {
        # Check if it's a real fragment like ") For given n 1012, compute"
        if ($stmt -match '^\)' -or $stmt -match '^\d') {
            # Garbage fragment — clear it
            $p.statement = ''
            if ($p.status -eq 'complete' -and (-not $p.solution -or $p.solution.Length -lt 50)) {
                $p.status = 'incomplete'
            }
            $counters['very_short_cleared']++
        }
    }
}

[Console]::Out.WriteLine("  Empty stmt fixed: $($counters['empty_stmt_fixed'])")
[Console]::Out.WriteLine("  Very short cleared: $($counters['very_short_cleared'])")

# ============================================================
# PASS 11: Fix type mismatches (discussion questions as "calculation")
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 11: Fix type mismatches ===")

foreach ($p in $active) {
    $stmt = if ($p.statement) { $p.statement } else { '' }
    $title = $p.title

    # Discussion/explain questions marked as calculation
    if ($p.type -eq 'calculation') {
        $text = "$title $stmt".ToLower()
        if ($text -match '(?i)^(discuss|explain|describe|compare|define|what is the (difference|relationship|meaning)|how does|why does|when should|what are the)' -or
            $stmt -match '(?i)^(discuss|explain|describe|compare and contrast|define|what is|how does|why does|when should|what are)') {
            $p.type = 'conceptual'
            $counters['type_fixed']++
        }
    }

    # Questions starting with "Discuss" or "Explain" should be conceptual
    if ($p.type -ne 'conceptual' -and $p.type -ne 'open-ended') {
        if ($title -match '^(Discuss|Explain|Describe|Compare|Define)\s') {
            $p.type = 'conceptual'
            $counters['type_fixed']++
        }
    }
}

[Console]::Out.WriteLine("  Type mismatches fixed: $($counters['type_fixed'])")

# ============================================================
# PASS 12: Title too long — truncate to key phrase
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 12: Fix too-long titles ===")

foreach ($p in $active) {
    if ($p.title.Length -gt 80) {
        $stmt = if ($p.statement) { $p.statement } else { '' }
        if ($stmt.Length -gt 20) {
            $newTitle = Generate-Title $stmt $p.category
            if ($newTitle -and $newTitle.Length -gt 8 -and $newTitle.Length -le 70) {
                $p.title = $newTitle
                $counters['title_too_long_fixed']++
            }
        }
        # If still too long, truncate at word boundary
        if ($p.title.Length -gt 80) {
            $truncated = $p.title.Substring(0, 75)
            $lastSpace = $truncated.LastIndexOf(' ')
            if ($lastSpace -gt 30) {
                $p.title = $truncated.Substring(0, $lastSpace)
                $counters['title_too_long_fixed']++
            }
        }
    }
}

[Console]::Out.WriteLine("  Too-long titles fixed: $($counters['title_too_long_fixed'])")

# ============================================================
# SAVE
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("FIX RESULTS (Round 2):")
$total = 0
foreach ($entry in ($counters.GetEnumerator() | Sort-Object Value -Descending)) {
    if ($entry.Value -gt 0) {
        [Console]::Out.WriteLine("  $($entry.Key): $($entry.Value)")
        $total += $entry.Value
    }
}
[Console]::Out.WriteLine("  TOTAL: $total")
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
