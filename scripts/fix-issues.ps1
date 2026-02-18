# Fix issues flagged in GitHub issues #4 and #5
$problemsPath = "$PSScriptRoot\..\data\problems.json"
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json

$lookup = @{}
for ($i = 0; $i -lt $problems.Count; $i++) {
    $lookup[$problems[$i].id] = $i
}

$changes = 0

# ============ ISSUE #4: Near-duplicate pairs ============
# Mark the duplicate copies (keep the lower ID as canonical)
$markDuplicate = @(1671, 1592, 1617, 1302, 1259, 1258)
foreach ($id in $markDuplicate) {
    $idx = $lookup[$id]
    if ($null -ne $idx -and $problems[$idx].status -ne 'duplicate') {
        $problems[$idx].status = 'duplicate'
        [Console]::Out.WriteLine("Marked ID $id as duplicate: $($problems[$idx].title)")
        $changes++
    }
}

# ============ ISSUE #5: Vague/duplicate prompts ============
# Linear Regression Assumptions - keep ID 852 (most concise), mark 978, 1035, 1050 as duplicate
$linRegDupes = @(978, 1035, 1050)
foreach ($id in $linRegDupes) {
    $idx = $lookup[$id]
    if ($null -ne $idx -and $problems[$idx].status -ne 'duplicate') {
        $problems[$idx].status = 'duplicate'
        [Console]::Out.WriteLine("Marked ID $id as duplicate (linear regression dup): $($problems[$idx].title)")
        $changes++
    }
}

# Mark vague open-ended prompts that aren't interview-testable
$vagueIds = @(964) # "Project-Specific Questions" is not a real problem
foreach ($id in $vagueIds) {
    $idx = $lookup[$id]
    if ($null -ne $idx -and $problems[$idx].status -ne 'duplicate') {
        $problems[$idx].status = 'duplicate'
        [Console]::Out.WriteLine("Marked ID $id as duplicate (not testable): $($problems[$idx].title)")
        $changes++
    }
}

# ============ BROADER DUPLICATE SCAN ============
# Find more title-only problems that are near-duplicates of each other
$titleOnly = @($problems | Where-Object { $_.status -eq 'title-only' })
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Scanning $($titleOnly.Count) title-only problems for more duplicates...")

# Group by normalized title prefix (first 3 words)
$groups = @{}
foreach ($p in $titleOnly) {
    $words = ($p.title -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', ' ').Trim().ToLower() -split '\s+'
    $prefix = ($words | Select-Object -First 3) -join ' '
    if (-not $groups.ContainsKey($prefix)) { $groups[$prefix] = @() }
    $groups[$prefix] += $p
}

# Find groups with > 2 members (likely duplicates)
$extraDupes = 0
foreach ($entry in $groups.GetEnumerator()) {
    if ($entry.Value.Count -gt 2) {
        # Keep the first one, mark rest as duplicate
        $sorted = $entry.Value | Sort-Object id
        for ($i = 1; $i -lt $sorted.Count; $i++) {
            $idx = $lookup[$sorted[$i].id]
            if ($null -ne $idx -and $problems[$idx].status -ne 'duplicate') {
                $problems[$idx].status = 'duplicate'
                $extraDupes++
                $changes++
            }
        }
        if ($entry.Value.Count -gt 3) {
            [Console]::Out.WriteLine("  Group '$($entry.Key)': $($entry.Value.Count) items, kept $($sorted[0].id), duped $($entry.Value.Count - 1)")
        }
    }
}
[Console]::Out.WriteLine("  Extra title-only duplicates found: $extraDupes")

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Total changes: $changes")

# Save
[Console]::Out.WriteLine("Saving...")
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8

# Final status counts
$statuses = $problems | Group-Object status
foreach ($s in $statuses) { [Console]::Out.WriteLine("  $($s.Name): $($s.Count)") }
[Console]::Out.WriteLine("Done.")
