# Fix all issues found by audit-all.ps1
# Fixes: broken titles, placeholder stmts, raw latex macros, missing tags, wrong categories

$problemsPath = "$PSScriptRoot\..\data\problems.json"
[Console]::Out.WriteLine("Loading problems.json...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
[Console]::Out.WriteLine("  Total: $($problems.Count)")

$byId = @{}
foreach ($p in $problems) { $byId[$p.id] = $p }

$counters = @{
    title_fixed = 0
    placeholder_cleared = 0
    latex_macro_fixed = 0
    tags_added = 0
    category_fixed = 0
    empty_stmt_fixed = 0
}

# Stopwords for title generation
$stopWords = @('the','and','for','that','this','with','from','have','been','will','would','could','should','which','their','there','they','about','after','before','being','between','both','during','each','than','then','these','those','through','under','very','what','when','where','while','into','most','much','must','only','other','over','same','some','such','also','just','like','make','many','more','need','find','given','know','take','want','does','using','used','consider','following','problem','question','answer','solution','solve','determine','calculate','compute','show','prove','explain','suppose','assume','let','define','note','hint','example','task','context','asked','round','interview','write','implement','return','input','output','function','class','method','are','was','were','has','had','its','you','your','can','not','how','all','one','two','three','four','five','first','second','new','way','may','part','get','got','say','set','try','too','use','her','him','his','she','see','now','old','big','come','made','think','every','give','well','our','back')

function Generate-Title($stmt, $category) {
    if (-not $stmt -or $stmt.Length -lt 10) { return $null }

    # Strip LaTeX for analysis
    $clean = $stmt -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+\{[^}]*\}', '' -replace '\\[a-zA-Z]+', ''
    $clean = $clean -replace '[^a-zA-Z0-9\s,.]', ' ' -replace '\s+', ' '
    $clean = $clean.Trim()

    # Try to extract first meaningful sentence (up to first period or question mark)
    $firstSent = ($clean -split '[.?]')[0].Trim()
    if ($firstSent.Length -gt 10 -and $firstSent.Length -le 70) {
        # Clean up: capitalize first letter, remove trailing conjunctions
        $firstSent = $firstSent -replace '\s+(and|or|the|a|an|is|are|in|of|to|for|with|that|which)\s*$', ''
        $firstSent = $firstSent.Trim()
        if ($firstSent.Length -gt 10) {
            # Title case
            $words = $firstSent -split '\s+'
            $titled = @()
            foreach ($w in $words) {
                if ($w.Length -le 3 -and $w -in $stopWords -and $titled.Count -gt 0) {
                    $titled += $w
                } else {
                    $titled += $w.Substring(0,1).ToUpper() + $w.Substring(1)
                }
            }
            return ($titled -join ' ')
        }
    }

    # Fallback: extract key nouns from first 100 chars
    $words = @($clean.Substring(0, [math]::Min(100, $clean.Length)) -split '\s+' | Where-Object { $_.Length -gt 3 -and $_.ToLower() -notin $stopWords } | Select-Object -First 6)
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
    return @($tags | Sort-Object -Unique)
}

# ============ PASS 1: FIX BROKEN TITLES ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 1: Fix broken titles ===")

foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    $title = $p.title
    $stmt = if ($p.statement) { $p.statement } else { '' }

    $needsFix = $false

    # Fragment title (starts with lowercase preposition/article/conjunction)
    if ($title -match '^(of |the |and |is |are |to |in |for |a |an |that |with |from |by |at |on |or |as |it |if |be |do |so |but |not |we |you |he |she )') {
        $needsFix = $true
    }
    # Trailing preposition (truncated)
    if ($title -match '\s(the|and|or|of|to|in|for|with|a|an|is|are|that|which|from|by|at|on|as|if|but|not|into|than|its|this|these|those|when|where|how|what|who)\s*$') {
        $needsFix = $true
    }

    if ($needsFix -and $stmt.Length -gt 20) {
        $newTitle = Generate-Title $stmt $p.category
        if ($newTitle -and $newTitle.Length -gt 8 -and $newTitle.Length -le 70) {
            $p.title = $newTitle
            $counters['title_fixed']++
        }
    }
}

[Console]::Out.WriteLine("  Titles fixed: $($counters['title_fixed'])")

# ============ PASS 2: FIX TITLE_IS_STMT (too-long titles that are the statement) ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 2: Fix title-is-statement duplicates ===")

$titleStmtFixed = 0
foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    $title = $p.title
    $stmt = if ($p.statement) { $p.statement } else { '' }

    # Only fix if title is long AND matches statement start
    if ($title.Length -gt 50 -and $stmt.Length -gt 30) {
        $titleNorm = $title.ToLower() -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
        $stmtNorm = ($stmt -split '\n')[0].ToLower() -replace '[^a-z0-9\s]', '' -replace '\s+', ' '

        if ($stmtNorm.Length -gt 20 -and $titleNorm.Length -gt 20) {
            $checkLen = [math]::Min(25, [math]::Min($titleNorm.Length, $stmtNorm.Length))
            if ($titleNorm.Substring(0, $checkLen) -eq $stmtNorm.Substring(0, $checkLen)) {
                $newTitle = Generate-Title $stmt $p.category
                if ($newTitle -and $newTitle.Length -gt 8 -and $newTitle.Length -le 70 -and $newTitle.Length -lt $title.Length) {
                    $p.title = $newTitle
                    $titleStmtFixed++
                }
            }
        }
    }
}
$counters['title_fixed'] += $titleStmtFixed
[Console]::Out.WriteLine("  Title-is-stmt fixed: $titleStmtFixed")

# ============ PASS 3: FIX PLACEHOLDER STATEMENTS ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 3: Clear placeholder statements ===")

foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    $stmt = if ($p.statement) { $p.statement } else { '' }

    if ($stmt -match '^Solve this \w[\w\-]* problem:') {
        # Clear the useless statement - keep only the title
        $p.statement = ''
        if ($p.status -eq 'complete' -and (-not $p.solution -or $p.solution.Length -lt 50)) {
            $p.status = 'incomplete'
        }
        $counters['placeholder_cleared']++
    }
}

[Console]::Out.WriteLine("  Placeholders cleared: $($counters['placeholder_cleared'])")

# ============ PASS 4: FIX RAW LATEX MACROS ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 4: Fix raw LaTeX macros ===")

foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    $stmt = if ($p.statement) { $p.statement } else { '' }
    $sol = if ($p.solution) { $p.solution } else { '' }

    $macroPattern = '\\(corr|unif|ev|prob|binomial|expected|var|cov|indicator|floor|ceil)\{'
    if ($stmt -match $macroPattern -or $sol -match $macroPattern) {
        $replacements = @(
            @('\\corr\{([^}]*)\}\{([^}]*)\}', '\text{Corr}($1, $2)'),
            @('\\corr\{([^}]*)\}', '\text{Corr}($1)'),
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
            if ($p.statement) { $p.statement = $p.statement -replace $r[0], $r[1] }
            if ($p.solution) { $p.solution = $p.solution -replace $r[0], $r[1] }
        }
        $counters['latex_macro_fixed']++
    }
}

[Console]::Out.WriteLine("  LaTeX macros fixed: $($counters['latex_macro_fixed'])")

# ============ PASS 5: FIX MISSING TAGS ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 5: Auto-tag problems with no tags ===")

foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
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
        }
    }
}

[Console]::Out.WriteLine("  Problems auto-tagged: $($counters['tags_added'])")

# ============ PASS 6: FIX WRONG CATEGORIES ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 6: Fix wrong categories ===")

# Should be optimization
$optIds = @(297,735,1188,1322,1409,1526,1574,1942,2002,2139,2699,2800,2899,3047,3116,3306,4579,4616,4637)
foreach ($id in $optIds) {
    if ($byId.ContainsKey($id)) {
        $p = $byId[$id]
        if ($p.status -ne 'duplicate' -and $p.category -eq 'probability') {
            $p.category = 'optimization'
            $p.type = 'conceptual'
            $counters['category_fixed']++
        }
    }
}

# Should be coding
$codeIds = @(570,874,3196,3732)
foreach ($id in $codeIds) {
    if ($byId.ContainsKey($id)) {
        $p = $byId[$id]
        if ($p.status -ne 'duplicate') {
            $p.category = 'coding'
            $p.type = 'coding'
            $counters['category_fixed']++
        }
    }
}

[Console]::Out.WriteLine("  Categories fixed: $($counters['category_fixed'])")

# ============ PASS 7: FIX EMPTY STMT COMPLETE ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 7: Fix empty-statement complete problems ===")

foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }
    if ($p.status -eq 'complete' -and (-not $p.statement -or $p.statement.Length -eq 0)) {
        if (-not $p.solution -or $p.solution.Length -lt 50) {
            $p.status = 'incomplete'
            $counters['empty_stmt_fixed']++
        }
    }
}

[Console]::Out.WriteLine("  Empty-stmt fixed: $($counters['empty_stmt_fixed'])")

# ============ SAVE ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("FIX RESULTS:")
foreach ($entry in ($counters.GetEnumerator() | Sort-Object Value -Descending)) {
    if ($entry.Value -gt 0) {
        [Console]::Out.WriteLine("  $($entry.Key): $($entry.Value)")
    }
}
$total = ($counters.Values | Measure-Object -Sum).Sum
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
