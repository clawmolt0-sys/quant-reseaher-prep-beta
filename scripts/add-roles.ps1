# Add "roles" field to every problem in problems.json
# Roles: QR (Quant Researcher), QT (Quant Trader), SWE (Software Engineer)
# A problem can have multiple roles

$problemsPath = "$PSScriptRoot\..\data\problems.json"
[Console]::Out.WriteLine("Loading problems.json...")
$problems = Get-Content $problemsPath -Raw | ConvertFrom-Json
[Console]::Out.WriteLine("  Total problems: $($problems.Count)")

# Category -> Role mapping
$qrOnly = @('stochastic-process', 'statistics', 'regression', 'machine-learning', 'time-series', 'options-pricing', 'linear-algebra', 'optimization', 'differential-equations', 'numerical-methods')
$qtOnly = @('brain-teaser', 'game-theory', 'market-microstructure', 'finance', 'mental-math')
$sweOnly = @('coding')
$qrAndQt = @('probability', 'expectation', 'combinatorics', 'random-variables', 'sequences-series', 'calculus')

# QR-specific keywords (in tags or title)
$qrKeywords = @('regression', 'pca', 'eigenvalue', 'covariance', 'correlation', 'ito', 'stochastic', 'black-scholes', 'greeks', 'hedging', 'martingale', 'brownian', 'diffusion', 'vasicek', 'monte-carlo', 'numerical', 'ols', 'mle', 'maximum-likelihood', 'hypothesis-testing', 'confidence-interval', 'time-series', 'arima', 'garch', 'volatility-modeling', 'factor-model', 'risk-model', 'copula', 'var', 'cvar', 'optimization', 'convex', 'gradient', 'sde', 'pde', 'fourier', 'calibration', 'interpolation', 'spline', 'neural-network', 'machine-learning', 'regularization', 'cross-validation', 'backtest', 'sharpe', 'information-ratio', 'alpha', 'portfolio', 'mean-variance', 'markowitz')

# QT-specific keywords
$qtKeywords = @('brain-teaser', 'game', 'strategy', 'auction', 'bid', 'market-making', 'order-book', 'spread', 'tick', 'penny', 'dice', 'coin', 'card', 'puzzle', 'hat', 'prisoner', 'fermi', 'estimation', 'mental-math', 'arithmetic', 'speed-math', 'trading-strategy', 'market-microstructure', 'execution', 'slippage', 'latency')

# SWE-specific keywords
$sweKeywords = @('algorithm', 'data-structure', 'dynamic-programming', 'graph-algorithm', 'sorting', 'binary-search', 'linked-list', 'tree', 'hash', 'stack', 'queue', 'heap', 'python', 'c++', 'java', 'sql', 'database', 'api', 'system-design', 'oop', 'recursion', 'complexity', 'big-o')

$stats = @{ 'QR' = 0; 'QT' = 0; 'SWE' = 0; 'QR+QT' = 0; 'QR+SWE' = 0; 'QT+SWE' = 0; 'QR+QT+SWE' = 0 }

foreach ($p in $problems) {
    $roles = @()
    $cat = $p.category
    $tags = @()
    if ($p.tags) { $tags = @($p.tags) }
    $titleLower = if ($p.title) { $p.title.ToLower() } else { '' }

    # Step 1: Category-based classification
    if ($cat -in $qrOnly) {
        $roles += 'QR'
    } elseif ($cat -in $qtOnly) {
        $roles += 'QT'
    } elseif ($cat -in $sweOnly) {
        $roles += 'SWE'
    } elseif ($cat -in $qrAndQt) {
        $roles += 'QR'
        $roles += 'QT'
    }

    # Step 2: Keyword scan to add additional roles
    $allText = ($tags -join ' ') + ' ' + $titleLower

    # Check for QR keywords
    $hasQR = $false
    foreach ($kw in $qrKeywords) {
        if ($allText -match [regex]::Escape($kw)) { $hasQR = $true; break }
    }
    if ($hasQR -and 'QR' -notin $roles) { $roles += 'QR' }

    # Check for QT keywords
    $hasQT = $false
    foreach ($kw in $qtKeywords) {
        if ($allText -match [regex]::Escape($kw)) { $hasQT = $true; break }
    }
    if ($hasQT -and 'QT' -notin $roles) { $roles += 'QT' }

    # Check for SWE keywords
    $hasSWE = $false
    foreach ($kw in $sweKeywords) {
        if ($allText -match [regex]::Escape($kw)) { $hasSWE = $true; break }
    }
    if ($hasSWE -and 'SWE' -notin $roles) { $roles += 'SWE' }

    # Step 3: If no roles assigned (shouldn't happen often), default based on difficulty/type
    if ($roles.Count -eq 0) {
        # Default: QR+QT for math-heavy, QT for estimation/brain-teaser type
        if ($p.type -eq 'brain-teaser' -or $p.type -eq 'estimation') {
            $roles += 'QT'
        } else {
            $roles += 'QR'
            $roles += 'QT'
        }
    }

    # Deduplicate
    $roles = @($roles | Sort-Object -Unique)

    # Add to problem using PSObject
    if ($p.PSObject.Properties['roles']) {
        $p.roles = $roles
    } else {
        $p | Add-Member -NotePropertyName 'roles' -NotePropertyValue $roles -Force
    }

    # Track stats
    $key = $roles -join '+'
    if ($stats.ContainsKey($key)) { $stats[$key]++ } else { $stats[$key] = 1 }
}

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Role distribution:")
foreach ($entry in ($stats.GetEnumerator() | Sort-Object Value -Descending)) {
    [Console]::Out.WriteLine("  $($entry.Key): $($entry.Value)")
}

# Save
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Saving problems.json...")
$problems | ConvertTo-Json -Depth 10 -Compress | Set-Content $problemsPath -Encoding UTF8
$size = [math]::Round((Get-Item $problemsPath).Length / 1KB)
[Console]::Out.WriteLine("Done. File size: ${size} KB")
