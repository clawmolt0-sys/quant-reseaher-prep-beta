# Extract questions from PDFs in dump/ directories
# Outputs: data/ingest/pdf-converted.json
# Three parsing formats: Numbered, Topic-Task, Problem-N

param(
    [switch]$DryRun = $false
)

$dumpDir = "$PSScriptRoot\..\..\dump"
$outPath = "$PSScriptRoot\..\data\ingest\pdf-converted.json"
$pdftotext = "C:\Program Files\Git\mingw64\bin\pdftotext.exe"

# PDF file configs: path, company, format, skipDup
$pdfConfigs = @(
    # more_questions_pdf/ - Numbered format
    @{ path = "more_questions_pdf/Citadel_150.pdf"; company = "citadel"; format = "numbered"; role = "QR" }
    @{ path = "more_questions_pdf/JaneStreet.pdf"; company = "jane-street"; format = "numbered"; role = "QR" }
    @{ path = "more_questions_pdf/Two_Sigma.pdf"; company = "two-sigma"; format = "numbered"; role = "QR" }
    @{ path = "more_questions_pdf/Bank_of_America.pdf"; company = "bank-of-america"; format = "numbered"; role = "QR" }
    @{ path = "more_questions_pdf/Barclay.pdf"; company = "barclays"; format = "numbered"; role = "QR" }
    @{ path = "more_questions_pdf/Citi_Quant.pdf"; company = "citi"; format = "numbered"; role = "QR" }
    @{ path = "more_questions_pdf/HRT (1).pdf"; company = "hrt"; format = "numbered"; role = "QR" }
    @{ path = "more_questions_pdf/Old_Mission.pdf"; company = "old-mission"; format = "numbered"; role = "QR" }
    @{ path = "more_questions_pdf/Optiver (1).pdf"; company = "optiver"; format = "numbered"; role = "QT" }
    @{ path = "more_questions_pdf/Tower_Research_QR_QT.pdf"; company = "tower-research"; format = "numbered"; role = "QR" }
    @{ path = "more_questions_pdf/WorldQuant.pdf"; company = "worldquant"; format = "numbered"; role = "QR" }
    @{ path = "more_questions_pdf/jp_morgan.pdf"; company = "jpmorgan"; format = "numbered"; role = "QR" }
    # Akuna(1) is actually Two Sigma content
    @{ path = "more_questions_pdf/Akuna (1).pdf"; company = "two-sigma"; format = "numbered"; role = "QR" }

    # more_questions_pdf/ - Topic-Task format
    @{ path = "more_questions_pdf/Akuna.pdf"; company = "akuna"; format = "topic-task"; role = "QR" }
    @{ path = "more_questions_pdf/JumpTrading (1).pdf"; company = "jump-trading"; format = "topic-task"; role = "QR" }
    @{ path = "more_questions_pdf/JumpTrading (2).pdf"; company = "jump-trading"; format = "topic-task-extra"; role = "QR" }
    @{ path = "more_questions_pdf/IMC.pdf"; company = "imc"; format = "topic-task"; role = "QR" }
    @{ path = "more_questions_pdf/IMC_OA.pdf"; company = "imc"; format = "topic-task"; role = "SWE" }
    @{ path = "more_questions_pdf/Citadel_SWE_Technical_Interview_Question_Bank (1).pdf"; company = "citadel"; format = "topic-task"; role = "SWE" }

    # problems/ - Problem-N format
    @{ path = "problems/Citadel.pdf"; company = "citadel"; format = "problem-n"; role = "SWE" }
    @{ path = "problems/citadel_new.pdf"; company = "citadel"; format = "problem-n"; role = "QR" }
    @{ path = "problems/drw.pdf"; company = "drw"; format = "numbered-question"; role = "QR" }
    @{ path = "problems/HFT.pdf"; company = "hft"; format = "problem-n"; role = "SWE" }
    @{ path = "problems/HRT_math.pdf"; company = "hrt"; format = "problem-n"; role = "QR" }
    @{ path = "problems/jump_trading.pdf"; company = "jump-trading"; format = "problem-n"; role = "QR" }
    @{ path = "problems/optiver_demo2.pdf"; company = "optiver"; format = "point-n"; role = "QT" }
    @{ path = "problems/SIG.pdf"; company = "sig"; format = "problem-n"; role = "QT" }
    @{ path = "problems/squarepoint.pdf"; company = "squarepoint"; format = "problem-n"; role = "QR" }
    @{ path = "problems/tower.pdf"; company = "tower-research"; format = "problem-n"; role = "QR" }
    @{ path = "problems/two_sigma.pdf"; company = "two-sigma"; format = "problem-n"; role = "QR" }
)

# Skip list (image-only PDF, exact duplicates already handled by JumpTrading(2) extra merge)
$skipPdfs = @(
    "more_questions_pdf/2026 GS VI Department Specific Question - FICC and Equities.pdf"  # Image-only
)

$allQuestions = @()
$totalExtracted = 0

function Clean-Text($text) {
    if (-not $text) { return "" }
    # Fix common PDF extraction artifacts
    $text = $text -replace '\x0c', ''  # form feed
    $text = $text -replace '([a-z])-\r?\n([a-z])', '$1$2'  # rejoin hyphenated words
    $text = $text -replace '\r?\n(?=[a-z])', ' '  # rejoin wrapped lines (lowercase continuation)
    $text = $text -replace '\s+', ' '  # collapse whitespace
    $text = $text.Trim()
    return $text
}

function Extract-Numbered($text, $company, $role) {
    # Format: "1. Question text..." or "1. (Topic) Question text..."
    $questions = @()
    # Split on number-dot at start of line
    $parts = $text -split '(?m)(?=^\s*\d+\.\s)'
    foreach ($part in $parts) {
        $part = $part.Trim()
        if ($part -match '^\s*(\d+)\.\s+(.+)') {
            $num = $Matches[1]
            $body = $Matches[2]

            # Clean the body
            $body = Clean-Text $body

            # Skip very short entries
            if ($body.Length -lt 20) { continue }

            # Extract title: first sentence or parenthetical
            $title = ""
            if ($body -match '^\(([^)]+)\)\s*') {
                $title = $Matches[1]
                $body = $body -replace '^\([^)]+\)\s*', ''
            } elseif ($body -match '^([^.?!]{10,80})[.?!]') {
                $title = $Matches[1]
            } else {
                $title = if ($body.Length -gt 80) { $body.Substring(0, 80) } else { $body }
            }

            $questions += @{
                num = [int]$num
                title = $title.Trim()
                statement = $body.Trim()
                company = $company
                role = $role
            }
        }
    }
    return $questions
}

function Extract-TopicTask($text, $company, $role) {
    # Format: "1. [Topic] Context: ... Task: ..."
    $questions = @()
    $parts = $text -split '(?m)(?=^\s*\d+\.\s+\[)'
    foreach ($part in $parts) {
        $part = $part.Trim()
        if ($part -match '^\s*(\d+)\.\s+\[([^\]]+)\]\s*(.+)') {
            $num = $Matches[1]
            $topic = $Matches[2]
            $body = Clean-Text $Matches[3]

            if ($body.Length -lt 20) { continue }

            # Title from topic + first meaningful phrase
            $title = "$topic"
            if ($body -match 'Context:\s*(.{10,60}?)[.]') {
                $title = "$topic - $($Matches[1].Trim())"
            }

            $questions += @{
                num = [int]$num
                title = $title.Trim()
                statement = $body.Trim()
                company = $company
                role = $role
                tags = @($topic.ToLower() -replace '\s+', '-')
            }
        }
    }
    return $questions
}

function Extract-ProblemN($text, $company, $role) {
    # Format: "Problem 1: Title\nBody..." or "1 Problem 1: ..."
    $questions = @()
    $parts = $text -split '(?m)(?=(?:^\d+\s+)?Problem\s+\d+[:\s])'
    foreach ($part in $parts) {
        $part = $part.Trim()
        if ($part -match '(?:^\d+\s+)?Problem\s+(\d+)[:\s]+(.+)') {
            $num = $Matches[1]
            $body = Clean-Text $Matches[2]

            if ($body.Length -lt 20) { continue }

            # Title: first line or first sentence
            $title = ""
            if ($body -match '^([^.?!\n]{10,100}?)(?:[.?!\n]|$)') {
                $title = $Matches[1].Trim()
            } else {
                $title = if ($body.Length -gt 80) { $body.Substring(0, 80) } else { $body }
            }

            $questions += @{
                num = [int]$num
                title = $title.Trim()
                statement = $body.Trim()
                company = $company
                role = $role
            }
        }
    }
    return $questions
}

function Extract-PointN($text, $company, $role) {
    # Format: "Point 1: Title\nBody..."
    $questions = @()
    $parts = $text -split '(?m)(?=Point\s+\d+[:\s])'
    foreach ($part in $parts) {
        $part = $part.Trim()
        if ($part -match 'Point\s+(\d+)[:\s]+(.+)') {
            $num = $Matches[1]
            $body = Clean-Text $Matches[2]

            if ($body.Length -lt 20) { continue }

            $title = ""
            if ($body -match '^([^.?!\n]{10,100}?)(?:[.?!\n]|$)') {
                $title = $Matches[1].Trim()
            } else {
                $title = if ($body.Length -gt 80) { $body.Substring(0, 80) } else { $body }
            }

            $questions += @{
                num = [int]$num
                title = $title.Trim()
                statement = $body.Trim()
                company = $company
                role = $role
            }
        }
    }
    return $questions
}

function Extract-NumberedQuestion($text, $company, $role) {
    # Format: "Question 1\nBody..."
    $questions = @()
    $parts = $text -split '(?m)(?=Question\s+\d+)'
    foreach ($part in $parts) {
        $part = $part.Trim()
        if ($part -match 'Question\s+(\d+)\s*(.+)') {
            $num = $Matches[1]
            $body = Clean-Text $Matches[2]

            if ($body.Length -lt 20) { continue }

            $title = ""
            if ($body -match '^([^.?!\n]{10,100}?)(?:[.?!\n]|$)') {
                $title = $Matches[1].Trim()
            } else {
                $title = if ($body.Length -gt 80) { $body.Substring(0, 80) } else { $body }
            }

            $questions += @{
                num = [int]$num
                title = $title.Trim()
                statement = $body.Trim()
                company = $company
                role = $role
            }
        }
    }
    return $questions
}

# ============ PROCESS EACH PDF ============
foreach ($cfg in $pdfConfigs) {
    $pdfPath = "$dumpDir\$($cfg.path)"
    if (-not (Test-Path $pdfPath)) {
        [Console]::Out.WriteLine("SKIP (not found): $($cfg.path)")
        continue
    }
    if ($cfg.path -in $skipPdfs) {
        [Console]::Out.WriteLine("SKIP (blacklisted): $($cfg.path)")
        continue
    }

    # Extract text
    $text = & $pdftotext $pdfPath '-' 2>$null
    if (-not $text -or $text.Length -lt 50) {
        [Console]::Out.WriteLine("SKIP (no text): $($cfg.path)")
        continue
    }

    $questions = @()
    switch ($cfg.format) {
        'numbered' { $questions = Extract-Numbered $text $cfg.company $cfg.role }
        'topic-task' { $questions = Extract-TopicTask $text $cfg.company $cfg.role }
        'topic-task-extra' {
            # JumpTrading(2) has extra questions not in (1) - only extract those with num > some threshold
            $questions = Extract-TopicTask $text $cfg.company $cfg.role
        }
        'problem-n' { $questions = Extract-ProblemN $text $cfg.company $cfg.role }
        'point-n' { $questions = Extract-PointN $text $cfg.company $cfg.role }
        'numbered-question' { $questions = Extract-NumberedQuestion $text $cfg.company $cfg.role }
    }

    # Tag each question with source PDF
    foreach ($q in $questions) {
        $q['source_pdf'] = $cfg.path
    }

    $allQuestions += $questions
    $totalExtracted += $questions.Count
    [Console]::Out.WriteLine("  $($cfg.path): $($questions.Count) questions extracted")
}

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Total questions extracted: $totalExtracted")

# Convert to JSON-friendly format
$output = @()
foreach ($q in $allQuestions) {
    $entry = [PSCustomObject]@{
        title = $q.title
        statement = $q.statement
        company = $q.company
        role = $q.role
        source_pdf = $q.source_pdf
        tags = if ($q.tags) { $q.tags } else { @() }
    }
    $output += $entry
}

# Save
$output | ConvertTo-Json -Depth 5 -Compress | Set-Content $outPath -Encoding UTF8
$size = [math]::Round((Get-Item $outPath).Length / 1KB)
[Console]::Out.WriteLine("Saved to $outPath ($size KB)")
