# Fix Titles Round 3 — aggressively shorten TITLE_IS_STMT problems
# These 670 problems have titles that duplicate the statement opening.
# Strategy: Extract the CORE CONCEPT (3-8 words) rather than first sentence.

$problemsPath = "$PSScriptRoot\..\data\problems.json"
[Console]::Out.WriteLine("Loading problems.json...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
$active = @($problems | Where-Object { $_.status -ne 'duplicate' })
[Console]::Out.WriteLine("  Total: $($problems.Count), Active: $($active.Count)")

$smallWords = @('a','an','the','and','or','but','nor','for','yet','so','in','on','at','to','by','of','as','is','if','up','it','be','do','no','we','he','vs')

$stopWords = @('the','and','for','that','this','with','from','have','been','will','would','could','should','which','their','there','they','about','after','before','being','between','both','during','each','than','then','these','those','through','under','very','what','when','where','while','into','most','much','must','only','other','over','same','some','such','also','just','like','make','many','more','need','find','given','know','take','want','does','using','used','consider','following','problem','question','answer','solution','solve','determine','calculate','compute','show','prove','explain','suppose','assume','let','define','note','hint','example','task','context','asked','round','interview','write','implement','return','input','output','function','class','method','are','was','were','has','had','its','you','your','can','not','how','all','one','two','three','four','five','first','second','new','way','may','part','get','got','say','set','try','too','use','her','him','his','she','see','now','old','big','come','made','think','every','give','well','our','back','open')

function Title-Case($text) {
    $words = @($text -split '\s+')
    $result = @()
    for ($i = 0; $i -lt $words.Count; $i++) {
        $w = $words[$i]
        if ($w.Length -eq 0) { continue }
        if ($i -eq 0 -or $i -eq $words.Count - 1 -or $w.ToLower() -notin $smallWords) {
            $result += $w.Substring(0,1).ToUpper() + $w.Substring(1)
        } else {
            $result += $w.ToLower()
        }
    }
    return ($result -join ' ')
}

function Extract-CoreConcept($stmt, $category) {
    if (-not $stmt -or $stmt.Length -lt 15) { return $null }

    # Strip LaTeX but keep what's between $ signs as placeholder
    $clean = $stmt -replace '\$\$[^$]*\$\$', ' MATH ' -replace '\$[^$]*\$', ' MATH '
    $clean = $clean -replace '\\[a-zA-Z]+\{[^}]*\}', '' -replace '\\[a-zA-Z]+', ''
    $clean = $clean -replace '`', '' -replace '\\\$', ''
    $clean = $clean -replace '\s*MATH\s*', ' '
    $clean = $clean -replace '[^a-zA-Z0-9\s,.\-]', ' ' -replace '\s+', ' '
    $clean = $clean.Trim()

    if ($clean.Length -lt 10) { return $null }

    # Strategy 1: Look for key phrases that indicate the core concept
    # "Find the probability of/that..." → "Probability of ..."
    # "What is the expected value of..." → "Expected Value of ..."
    # "Compute/Calculate the ..." → "Computing ..."
    $keyPhrases = @(
        @('(?i)(?:find|compute|calculate|determine|what is)\s+the\s+(probability\s+(?:that|of)\s+\S+(?:\s+\S+){0,4})', '$1'),
        @('(?i)(?:find|compute|calculate|what is)\s+the\s+(expected\s+(?:value|number|cost|time|length|distance|area)\s+(?:of|for)\s+\S+(?:\s+\S+){0,3})', '$1'),
        @('(?i)(?:find|compute|calculate)\s+the\s+(\S+(?:\s+\S+){0,4})', '$1'),
        @('(?i)(?:prove|show)\s+that\s+(.{10,50})', 'Proving $1'),
        @('(?i)(?:how many|how much)\s+(.{5,40})', '$1'),
        @('(?i)(?:given|suppose|consider)\s+(?:a|an|that)?\s*(.{10,45})', '$1')
    )

    foreach ($kp in $keyPhrases) {
        if ($clean -match $kp[0]) {
            $extracted = $clean -replace ('.*?' + $kp[0] + '.*'), $kp[1]
            if ($extracted -ne $clean -and $extracted.Length -gt 5 -and $extracted.Length -le 60) {
                # Clean up trailing stop words
                $extracted = $extracted -replace '\s+(and|or|the|a|an|is|are|in|of|to|for|with|that|which|from|by|at|on|as|if|but|not|into|than|its)\s*$', ''
                $extracted = $extracted.Trim(' ,.')
                if ($extracted.Length -gt 5) {
                    return Title-Case $extracted
                }
            }
        }
    }

    # Strategy 2: Extract key content words (nouns, adjectives) from first 120 chars
    $firstPart = $clean.Substring(0, [math]::Min(120, $clean.Length))
    # Remove leading phrases
    $firstPart = $firstPart -replace '(?i)^(suppose|given|consider|assume|let|say|imagine|you have|you are|there (is|are)|we have)\s+(that\s+)?', ''
    $firstPart = $firstPart -replace '(?i)^(a|an|the)\s+', ''

    $words = @($firstPart -split '\s+' | Where-Object { $_.Length -gt 3 -and $_.ToLower() -notin $stopWords })

    if ($words.Count -ge 2) {
        # Take 3-6 key words
        $keyWords = @($words | Select-Object -First 6)
        $title = ($keyWords | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower() }) -join ' '
        if ($title.Length -gt 8 -and $title.Length -le 65) {
            return $title
        }
        # If too long, take fewer words
        $keyWords = @($words | Select-Object -First 4)
        $title = ($keyWords | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower() }) -join ' '
        return $title
    }

    return $null
}

# ============================================================
# PASS 1: Fix TITLE_IS_STMT — replace with shorter concept-based title
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 1: Fix title-is-statement (concept extraction) ===")

$titleFixed = 0
$titleKept = 0

foreach ($p in $active) {
    $title = $p.title
    $stmt = if ($p.statement) { $p.statement } else { '' }
    if ($title.Length -le 30 -or $stmt.Length -le 20) { continue }

    # Check if title duplicates statement start
    $titleNorm = $title.ToLower() -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
    $stmtFirst = ($stmt -split '\n')[0].Trim()
    $stmtNorm = $stmtFirst.ToLower() -replace '[^a-z0-9\s]', '' -replace '\s+', ' '

    if ($stmtNorm.Length -gt 20 -and $titleNorm.Length -gt 20) {
        $checkLen = [math]::Min(25, [math]::Min($titleNorm.Length, $stmtNorm.Length))
        if ($titleNorm.Substring(0, $checkLen) -eq $stmtNorm.Substring(0, $checkLen)) {
            # This is a TITLE_IS_STMT problem
            $newTitle = Extract-CoreConcept $stmt $p.category
            if ($newTitle -and $newTitle.Length -gt 8 -and $newTitle.Length -le 65 -and $newTitle.Length -lt ($title.Length - 5)) {
                # Verify new title is actually different from the old one
                $newNorm = $newTitle.ToLower() -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
                if ($newNorm.Substring(0, [math]::Min(15, $newNorm.Length)) -ne $titleNorm.Substring(0, [math]::Min(15, $titleNorm.Length))) {
                    $p.title = $newTitle
                    $titleFixed++
                } else {
                    $titleKept++
                }
            } else {
                $titleKept++
            }
        }
    }
}

[Console]::Out.WriteLine("  Titles shortened: $titleFixed")
[Console]::Out.WriteLine("  Titles kept (no better option): $titleKept")

# ============================================================
# PASS 2: Fix remaining BROKEN_TITLE_FRAGMENT
# ============================================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("=== PASS 2: Fix remaining broken fragment titles ===")

$fragFixed = 0

foreach ($p in $active) {
    $title = $p.title
    $stmt = if ($p.statement) { $p.statement } else { '' }

    if ($title -match '^(of |the |and |is |are |to |in |for |a |an |that |with |from |by |at |on |or |as |it |if |be |do |so |but |not |we |you |he |she )') {
        # Try concept extraction first
        if ($stmt.Length -gt 20) {
            $newTitle = Extract-CoreConcept $stmt $p.category
            if ($newTitle -and $newTitle.Length -gt 8 -and $newTitle.Length -le 65) {
                $p.title = $newTitle
                $fragFixed++
                continue
            }
        }

        # Fallback: strip leading articles and re-title-case
        $cleaned = $title -replace '^(Of |The |And |Is |Are |To |In |For |A |An |That |With |From |By |At |On |Or |As |It |If |Be |Do |So |But |Not |We |You |He |She )+', ''
        $cleaned = $cleaned.Trim(' ,')
        if ($cleaned.Length -gt 8) {
            $p.title = Title-Case $cleaned
            $fragFixed++
        }
    }

    # Also fix trailing prepositions
    if ($p.title -match '\s(the|and|or|of|to|in|for|with|a|an|is|are|that|which|from|by|at|on|as|if|but|not|into|than|its|this|these|those|when|where|how|what|who)\s*$') {
        $p.title = $p.title -replace '\s+(the|and|or|of|to|in|for|with|a|an|is|are|that|which|from|by|at|on|as|if|but|not|into|than|its|this|these|those|when|where|how|what|who)\s*$', ''
        $p.title = $p.title.Trim(' ,')
        $fragFixed++
    }
}

[Console]::Out.WriteLine("  Fragment titles fixed: $fragFixed")

# ============================================================
# SAVE
# ============================================================
$total = $titleFixed + $fragFixed

$statuses = $problems | Group-Object status | Sort-Object Count -Descending
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Status breakdown:")
foreach ($s in $statuses) { [Console]::Out.WriteLine("  $($s.Name): $($s.Count)") }

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("TOTAL FIXES: $total")

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Saving...")
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8
$size = [math]::Round((Get-Item $problemsPath).Length / 1KB)
[Console]::Out.WriteLine("  problems.json: ${size} KB")
[Console]::Out.WriteLine("Done.")
