# Merge PDF-extracted questions into problems.json with aggressive dedup
# Multi-layer dedup: fingerprint, title Jaccard, statement prefix, keyword similarity

$dataDir = "$PSScriptRoot\..\data"
$problemsPath = "$dataDir\problems.json"
$pdfPath = "$dataDir\ingest\pdf-converted.json"
$companiesPath = "$dataDir\companies.json"

[Console]::Out.WriteLine("Loading data...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
$pdfQuestions = Get-Content $pdfPath -Raw | ConvertFrom-Json
$companies = Get-Content $companiesPath -Raw | ConvertFrom-Json
[Console]::Out.WriteLine("  Existing problems: $($problems.Count)")
[Console]::Out.WriteLine("  PDF questions: $($pdfQuestions.Count)")

# Build lookups
$problemById = @{}
$problemIdx = @{}
for ($i = 0; $i -lt $problems.Count; $i++) {
    $problemById[$problems[$i].id] = $problems[$i]
    $problemIdx[$problems[$i].id] = $i
}

$companySet = @{}
foreach ($c in $companies) { $companySet[$c.id] = $true }

# ============ FINGERPRINT INDEX ============
# Build fingerprints for all non-duplicate existing problems
$fingerprints = @{}  # normalized title -> problem
$stmtPrefixes = @{} # normalized statement prefix -> problem
$titleWords = @{}    # category -> array of {id, words}

foreach ($p in $problems) {
    if ($p.status -eq 'duplicate') { continue }

    # Title fingerprint
    $fp = ($p.title.ToLower() -replace '[^a-z0-9]', '').Trim()
    if ($fp.Length -gt 5) {
        if (-not $fingerprints.ContainsKey($fp)) { $fingerprints[$fp] = @() }
        $fingerprints[$fp] += $p
    }

    # Statement prefix
    if ($p.statement -and $p.statement.Length -gt 30) {
        $norm = $p.statement.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
        $norm = $norm.Trim()
        if ($norm.Length -gt 20) {
            $prefix = $norm.Substring(0, [math]::Min(100, $norm.Length))
            if (-not $stmtPrefixes.ContainsKey($prefix)) { $stmtPrefixes[$prefix] = @() }
            $stmtPrefixes[$prefix] += $p
        }
    }

    # Title word sets by category
    $cat = $p.category
    if (-not $titleWords.ContainsKey($cat)) { $titleWords[$cat] = @() }
    $words = @($p.title.ToLower() -split '[^a-zA-Z0-9]+' | Where-Object { $_.Length -gt 2 })
    $titleWords[$cat] += @{ id = $p.id; words = $words; problem = $p }
}

[Console]::Out.WriteLine("  Fingerprints: $($fingerprints.Count)")
[Console]::Out.WriteLine("  Statement prefixes: $($stmtPrefixes.Count)")

# ============ SIMILARITY FUNCTIONS ============
function Get-TitleJaccard($words1, $words2) {
    if ($words1.Count -eq 0 -or $words2.Count -eq 0) { return 0 }
    $set1 = @{}; foreach ($w in $words1) { $set1[$w] = $true }
    $set2 = @{}; foreach ($w in $words2) { $set2[$w] = $true }
    $intersection = 0
    foreach ($w in $set1.Keys) { if ($set2.ContainsKey($w)) { $intersection++ } }
    $union = $set1.Count + $set2.Count - $intersection
    if ($union -eq 0) { return 0 }
    return [math]::Round($intersection / $union, 3)
}

function Get-StmtMatch($s1, $s2) {
    if (-not $s1 -or -not $s2) { return 0 }
    $n1 = $s1.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
    $n2 = $s2.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
    $n1 = $n1.Trim(); $n2 = $n2.Trim()
    if ($n1.Length -lt 20 -or $n2.Length -lt 20) { return 0 }
    $len = [math]::Min(150, [math]::Min($n1.Length, $n2.Length))
    $sub1 = $n1.Substring(0, $len); $sub2 = $n2.Substring(0, $len)
    $matches = 0
    for ($i = 0; $i -lt $len; $i++) { if ($sub1[$i] -eq $sub2[$i]) { $matches++ } }
    return [math]::Round($matches / $len, 3)
}

function Get-Keywords($text) {
    if (-not $text) { return @() }
    $lower = $text.ToLower()
    $lower = $lower -replace '\$[^$]+\$', ''
    $lower = $lower -replace '\\[a-zA-Z]+', ''
    $words = @($lower -split '[^a-zA-Z0-9]+' | Where-Object { $_.Length -gt 3 })
    $stopWords = @('that','this','with','from','have','been','will','would','could','should','which','their','there','they','about','after','before','being','between','both','during','each','than','then','these','those','through','under','very','what','when','where','while','into','most','much','must','only','other','over','same','some','such','also','just','like','make','many','more','need','find','given','know','take','want','does','using','used','consider','following','problem','question','answer','solution','solve','determine','calculate','compute','show','prove','explain','suppose','assume')
    return @($words | Where-Object { $_ -notin $stopWords } | Sort-Object -Unique)
}

function Classify-Category($title, $statement, $tags, $role) {
    $text = "$title $statement".ToLower()

    # Keyword-based classification
    if ($text -match 'code|algorithm|data structure|implement|function|array|string|hash|tree|graph algorithm|dynamic programming|leetcode|python|c\+\+') { return 'coding' }
    if ($text -match 'black.?scholes|option.?pric|greeks|delta.?hedg|volatility surface|implied vol|call.*put|put.*call|european.*option|american.*option') { return 'options-pricing' }
    if ($text -match 'stochastic|brownian|ito|diffusion|sde|martingale|wiener') { return 'stochastic-process' }
    if ($text -match 'regression|ols|ordinary least|r.?squared|multicollinear|heteroskedast') { return 'regression' }
    if ($text -match 'machine.?learn|neural|gradient.*descent|regulariz|lasso|ridge|cross.?valid|overfitting|bias.?variance|svm|random.?forest|boosting|pca|clustering') { return 'machine-learning' }
    if ($text -match 'time.?series|arima|garch|autocorrelat|stationarity|forecast') { return 'time-series' }
    if ($text -match 'hypothesis.*test|p.?value|confidence.*interval|chi.?square|t.?test|z.?test|type.*error|significance|power.*test|central.*limit') { return 'statistics' }
    if ($text -match 'eigenvalue|eigenvector|matrix|determinant|linear.*algebra|rank|trace|singular.*value|positive.*definite|orthogonal') { return 'linear-algebra' }
    if ($text -match 'optimize|convex|lagrange|gradient|minimize|maximize|linear.*program|constraint') { return 'optimization' }
    if ($text -match 'market.?mak|order.?book|bid.?ask|spread|adverse.*select|microstructure|execution|latency|tick') { return 'market-microstructure' }
    if ($text -match 'game.*theory|nash|equilibrium|strategy|auction|mechanism.*design|minimax') { return 'game-theory' }
    if ($text -match 'brain.*teas|puzzle|logic|hat|prisoner|pirate|marble|balance|weighing|fermi|estimation|mental.*math|dice.*game') { return 'brain-teaser' }
    if ($text -match 'combinatori|permutation|combination|binomial|counting|choose|arrangement|stirling|catalan') { return 'combinatorics' }
    if ($text -match 'expected|expectation|expected.*value|linearity.*expectation') { return 'expectation' }
    if ($text -match 'random.*variable|distribution|pdf|cdf|pmf|moment.*generat|normal|poisson|exponential|uniform|bernoulli|geometric|binomial.*distrib') { return 'random-variables' }
    if ($text -match 'conditional.*prob|bayes|probability|likely|chance|odds|independent') { return 'probability' }
    if ($text -match 'sharpe|portfolio|risk.*return|capm|factor|alpha|beta.*finance|hedge|trading.*strateg') { return 'finance' }

    # Fallback based on role
    if ($role -eq 'SWE') { return 'coding' }
    if ($role -eq 'QT') { return 'probability' }
    return 'probability'
}

function Classify-Difficulty($statement) {
    if (-not $statement) { return 'medium' }
    $len = $statement.Length
    if ($len -gt 500) { return 'hard' }
    if ($len -lt 150) { return 'easy' }
    return 'medium'
}

function Classify-Type($statement, $category) {
    if ($category -eq 'coding') { return 'coding' }
    if ($category -eq 'brain-teaser') { return 'brain-teaser' }
    $text = "$statement".ToLower()
    if ($text -match 'prove|show that|demonstrate') { return 'proof' }
    if ($text -match 'estimate|approximate|fermi|order.*magnitude|how many') { return 'estimation' }
    if ($text -match 'strategy|optimal|maximize|minimize.*payoff') { return 'strategy' }
    if ($text -match 'compute|calculate|find.*value|derive|evaluate|what is') { return 'calculation' }
    if ($text -match 'explain|describe|discuss|conceptual|interpret') { return 'conceptual' }
    return 'calculation'
}

# ============ DEDUP AND MERGE ============
$nextId = ($problems | ForEach-Object { $_.id } | Measure-Object -Maximum).Maximum + 1
$added = 0
$skippedDup = 0
$companiesMerged = 0
$crossPdfDups = 0

# Also build an index of new questions (for cross-PDF dedup)
$newFingerprints = @{}
$newStmtPrefixes = @{}

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Processing $($pdfQuestions.Count) PDF questions...")

foreach ($q in $pdfQuestions) {
    $title = $q.title
    $stmt = $q.statement
    $company = $q.company
    $sourcePdf = $q.source_pdf

    if (-not $title -or $title.Length -lt 5) { continue }
    if (-not $stmt -or $stmt.Length -lt 20) { continue }

    $isDup = $false
    $dupOf = $null
    $dupReason = ""

    # ---- Layer 1: Title fingerprint match ----
    $fp = ($title.ToLower() -replace '[^a-z0-9]', '').Trim()
    if ($fp.Length -gt 5 -and $fingerprints.ContainsKey($fp)) {
        $isDup = $true
        $dupOf = $fingerprints[$fp][0]
        $dupReason = "exact title fingerprint"
    }

    # ---- Layer 1b: Cross-PDF fingerprint ----
    if (-not $isDup -and $newFingerprints.ContainsKey($fp)) {
        $crossPdfDups++
        $isDup = $true
        $dupReason = "cross-PDF exact title"
        # Skip entirely (don't even merge company since it's same source type)
        $skippedDup++
        continue
    }

    # ---- Layer 2: Statement prefix match ----
    if (-not $isDup -and $stmt.Length -gt 30) {
        $normStmt = $stmt.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
        $normStmt = $normStmt.Trim()
        if ($normStmt.Length -gt 20) {
            $prefix = $normStmt.Substring(0, [math]::Min(100, $normStmt.Length))
            if ($stmtPrefixes.ContainsKey($prefix)) {
                $isDup = $true
                $dupOf = $stmtPrefixes[$prefix][0]
                $dupReason = "exact statement prefix"
            }
            # Cross-PDF statement prefix
            if (-not $isDup -and $newStmtPrefixes.ContainsKey($prefix)) {
                $crossPdfDups++
                $isDup = $true
                $dupReason = "cross-PDF statement prefix"
                $skippedDup++
                continue
            }
        }
    }

    # ---- Layer 3: Title Jaccard against same-category problems ----
    if (-not $isDup) {
        $newWords = @($title.ToLower() -split '[^a-zA-Z0-9]+' | Where-Object { $_.Length -gt 2 })
        $category = Classify-Category $title $stmt $q.tags $q.role

        if ($titleWords.ContainsKey($category) -and $newWords.Count -gt 0) {
            $bestJac = 0
            $bestMatch = $null
            foreach ($existing in $titleWords[$category]) {
                $jac = Get-TitleJaccard $newWords $existing.words
                if ($jac -gt $bestJac) {
                    $bestJac = $jac
                    $bestMatch = $existing.problem
                }
            }

            if ($bestJac -ge 0.7 -and $bestMatch) {
                # Also check statement similarity for confidence
                $stmtSim = Get-StmtMatch $stmt $bestMatch.statement
                if ($bestJac -ge 0.85 -or ($bestJac -ge 0.7 -and $stmtSim -ge 0.5)) {
                    $isDup = $true
                    $dupOf = $bestMatch
                    $dupReason = "title Jaccard=$bestJac, stmt=$stmtSim"
                }
            }
        }

        # Also check ALL categories for high Jaccard (cross-domain duplicates)
        if (-not $isDup -and $newWords.Count -gt 2) {
            foreach ($cat in $titleWords.Keys) {
                if ($cat -eq $category) { continue }
                foreach ($existing in $titleWords[$cat]) {
                    $jac = Get-TitleJaccard $newWords $existing.words
                    if ($jac -ge 0.85) {
                        $stmtSim = Get-StmtMatch $stmt $existing.problem.statement
                        if ($stmtSim -ge 0.5) {
                            $isDup = $true
                            $dupOf = $existing.problem
                            $dupReason = "cross-cat title Jaccard=$jac, stmt=$stmtSim"
                            break
                        }
                    }
                }
                if ($isDup) { break }
            }
        }
    }

    # ---- Layer 4: Keyword-based similarity (from expand-graph.ps1 logic) ----
    if (-not $isDup) {
        $newKw = Get-Keywords $stmt
        $category = Classify-Category $title $stmt $q.tags $q.role

        if ($newKw.Count -gt 3 -and $titleWords.ContainsKey($category)) {
            $bestKwScore = 0
            $bestKwMatch = $null
            # Sample up to 200 problems in same category for keyword check
            $sampleSize = [math]::Min(200, $titleWords[$category].Count)
            $sample = $titleWords[$category] | Select-Object -First $sampleSize

            foreach ($existing in $sample) {
                $existKw = Get-Keywords $existing.problem.statement
                if ($existKw.Count -lt 3) { continue }
                $shared = @($newKw | Where-Object { $_ -in $existKw })
                if ($shared.Count -gt 0) {
                    $overlap = $shared.Count / [math]::Max(1, [math]::Min($newKw.Count, $existKw.Count))
                    if ($overlap -gt $bestKwScore) {
                        $bestKwScore = $overlap
                        $bestKwMatch = $existing.problem
                    }
                }
            }

            if ($bestKwScore -ge 0.7 -and $bestKwMatch) {
                $stmtSim = Get-StmtMatch $stmt $bestKwMatch.statement
                $titleJac = Get-TitleJaccard $newWords $(@($bestKwMatch.title.ToLower() -split '[^a-zA-Z0-9]+' | Where-Object { $_.Length -gt 2 }))
                if ($stmtSim -ge 0.6 -or $titleJac -ge 0.6) {
                    $isDup = $true
                    $dupOf = $bestKwMatch
                    $dupReason = "keyword overlap=$([math]::Round($bestKwScore,2)), stmt=$stmtSim, title=$titleJac"
                }
            }
        }
    }

    if ($isDup) {
        $skippedDup++

        # Merge company tag into existing problem
        if ($dupOf -and $company) {
            $existingCompanies = @($dupOf.companies)
            if ($company -notin $existingCompanies) {
                $dupOf.companies = @($existingCompanies + $company)
                $companiesMerged++
            }
        }

        if ($skippedDup -le 50 -or $skippedDup % 100 -eq 0) {
            $dupId = if ($dupOf) { $dupOf.id } else { "N/A" }
            [Console]::Out.WriteLine("  DUP #${skippedDup}: '$($title.Substring(0, [math]::Min(50, $title.Length)))...' -> ID $dupId ($dupReason)")
        }
    } else {
        # Add as new problem
        $category = Classify-Category $title $stmt $q.tags $q.role
        $difficulty = Classify-Difficulty $stmt
        $type = Classify-Type $stmt $category

        # Determine roles
        $roles = @()
        if ($q.role -eq 'QR') { $roles += 'QR' }
        elseif ($q.role -eq 'QT') { $roles += 'QT' }
        elseif ($q.role -eq 'SWE') { $roles += 'SWE' }
        else { $roles += 'QR'; $roles += 'QT' }
        # QR/QT overlap categories get both
        $bothCats = @('probability', 'expectation', 'combinatorics', 'random-variables')
        if ($category -in $bothCats) {
            if ('QR' -notin $roles) { $roles += 'QR' }
            if ('QT' -notin $roles) { $roles += 'QT' }
        }

        $newProblem = [PSCustomObject]@{
            id = $nextId
            title = $title
            category = $category
            difficulty = $difficulty
            type = $type
            status = 'incomplete'
            statement = $stmt
            solution = ''
            companies = @($company)
            tags = @()
            source = "pdf-$($sourcePdf -replace '[^a-zA-Z0-9]', '_')"
            roles = @($roles | Sort-Object -Unique)
        }

        $problems += $newProblem
        $problemById[$nextId] = $newProblem
        $problemIdx[$nextId] = $problems.Count - 1

        # Update indexes
        if ($fp.Length -gt 5) {
            if (-not $fingerprints.ContainsKey($fp)) { $fingerprints[$fp] = @() }
            $fingerprints[$fp] += $newProblem
            $newFingerprints[$fp] = $true
        }
        if ($stmt.Length -gt 30) {
            $normStmt = $stmt.ToLower() -replace '\$[^$]*\$', '' -replace '\\[a-zA-Z]+', '' -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
            $normStmt = $normStmt.Trim()
            if ($normStmt.Length -gt 20) {
                $prefix = $normStmt.Substring(0, [math]::Min(100, $normStmt.Length))
                if (-not $stmtPrefixes.ContainsKey($prefix)) { $stmtPrefixes[$prefix] = @() }
                $stmtPrefixes[$prefix] += $newProblem
                $newStmtPrefixes[$prefix] = $true
            }
        }
        $words = @($title.ToLower() -split '[^a-zA-Z0-9]+' | Where-Object { $_.Length -gt 2 })
        if (-not $titleWords.ContainsKey($category)) { $titleWords[$category] = @() }
        $titleWords[$category] += @{ id = $nextId; words = $words; problem = $newProblem }

        # Add company if new
        if ($company -and -not $companySet.ContainsKey($company)) {
            $displayName = [regex]::Replace(($company -replace '-', ' '), '\b(\w)', { param($m) $m.Groups[1].Value.ToUpper() })
            $companies += [PSCustomObject]@{
                id = $company
                name = $displayName
                type = "Trading Firm"
                roles = @("Quant")
            }
            $companySet[$company] = $true
        }

        $nextId++
        $added++
    }
}

# ============ REPORT ============
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=========================================")
[Console]::Out.WriteLine("PDF MERGE RESULTS:")
[Console]::Out.WriteLine("  Total PDF questions: $($pdfQuestions.Count)")
[Console]::Out.WriteLine("  Skipped as duplicate: $skippedDup")
[Console]::Out.WriteLine("    (of which cross-PDF: $crossPdfDups)")
[Console]::Out.WriteLine("  NEW problems added: $added")
[Console]::Out.WriteLine("  Companies merged into existing: $companiesMerged")
[Console]::Out.WriteLine("  Dedup rate: $([math]::Round($skippedDup / $pdfQuestions.Count * 100, 1))%")
[Console]::Out.WriteLine("=========================================")

# Final status breakdown
$statuses = $problems | Group-Object status
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Final status breakdown:")
foreach ($s in ($statuses | Sort-Object Count -Descending)) {
    [Console]::Out.WriteLine("  $($s.Name): $($s.Count)")
}
[Console]::Out.WriteLine("  TOTAL: $($problems.Count)")

# Save
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Saving problems.json...")
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8
$size = [math]::Round((Get-Item $problemsPath).Length / 1KB)
[Console]::Out.WriteLine("problems.json: ${size} KB")

[Console]::Out.WriteLine("Saving companies.json...")
$companies | ConvertTo-Json -Depth 5 | Set-Content $companiesPath -Encoding UTF8
$size = [math]::Round((Get-Item $companiesPath).Length / 1KB, 1)
[Console]::Out.WriteLine("companies.json: ${size} KB")
