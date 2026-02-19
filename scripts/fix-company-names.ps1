# Fix corrupted company names in companies.json
# The merge-corpus.ps1 bug stringified the PowerShell script block instead of evaluating it
# This regenerates proper display names from the id field

$companiesPath = "$PSScriptRoot\..\data\companies.json"
$companies = Get-Content $companiesPath -Raw | ConvertFrom-Json

# Manual overrides for known abbreviations and special names
$overrides = @{
    'hrt' = 'Hudson River Trading (HRT)'
    'drw' = 'DRW'
    'sig' = 'Susquehanna (SIG)'
    'aqr' = 'AQR Capital Management'
    'imc' = 'IMC Trading'
    'bnp-paribas' = 'BNP Paribas'
    'jpmorgan' = 'JPMorgan Chase'
    'jp-morgan' = 'JPMorgan Chase'
    'de-shaw' = 'D.E. Shaw'
    'goldman-sachs' = 'Goldman Sachs'
    'morgan-stanley' = 'Morgan Stanley'
    'bank-of-america' = 'Bank of America'
    'barclays' = 'Barclays'
    'deutsche-bank' = 'Deutsche Bank'
    'ubs' = 'UBS'
    'hsbc' = 'HSBC'
    'citi' = 'Citi'
    'citigroup' = 'Citigroup'
    'credit-suisse' = 'Credit Suisse'
    'hft' = 'HFT Research'
    'dv-trading' = 'DV Trading'
    'xr-trading' = 'XR Trading'
    'ssc' = 'SSC'
    'rbc' = 'RBC Capital Markets'
    'cme' = 'CME Group'
    'ibm' = 'IBM'
    'meta' = 'Meta'
    'pdp-capital' = 'PDP Capital'
    'nyu' = 'NYU'
    'mit' = 'MIT'
    'kcg' = 'KCG Holdings'
    'pdt-partners' = 'PDT Partners'
    'two-sigma' = 'Two Sigma'
    'citadel' = 'Citadel / Citadel Securities'
    'jane-street' = 'Jane Street'
    'jump-trading' = 'Jump Trading'
    'tower-research' = 'Tower Research Capital'
    'five-rings' = 'Five Rings Capital'
    'optiver' = 'Optiver'
    'squarepoint' = 'Squarepoint Capital'
    'millennium' = 'Millennium Management'
    'point72' = 'Point72'
    'renaissance' = 'Renaissance Technologies'
    'worldquant' = 'WorldQuant'
    'cubist' = 'Cubist Systematic'
    'bridgewater' = 'Bridgewater Associates'
    'man-group' = 'Man Group'
    'winton' = 'Winton Group'
    'balyasny' = 'Balyasny Asset Management'
    'wolverine' = 'Wolverine Trading'
    'akuna' = 'Akuna Capital'
    'belvedere' = 'Belvedere Trading'
    'old-mission' = 'Old Mission Capital'
    'transmarket-group' = 'TransMarket Group'
    'virtu' = 'Virtu Financial'
    'flow-traders' = 'Flow Traders'
    'maven' = 'Maven Securities'
    'peak6' = 'PEAK6 Investments'
    'voleon' = 'Voleon Group'
    'dimensional' = 'Dimensional Fund Advisors'
    'quantlab' = 'Quantlab Financial'
    'radix-trading' = 'Radix Trading'
    'headlands' = 'Headlands Technologies'
    'group-one' = 'Group One Trading'
    'chicago-trading' = 'Chicago Trading Company'
    'cutler-group' = 'Cutler Group'
    'allston-trading' = 'Allston Trading'
    'spot-trading' = 'Spot Trading'
    'tradelink' = 'TradeLink Securities'
    'gelber-group' = 'Gelber Group'
    'ronin-capital' = 'Ronin Capital'
    'tgs-management' = 'TGS Management'
    'quantitative-brokers' = 'Quantitative Brokers'
    'g-research' = 'G-Research'
    'marshall-wace' = 'Marshall Wace'
    'brevan-howard' = 'Brevan Howard'
    'capula' = 'Capula Investment Management'
    'blackrock' = 'BlackRock'
    'vanguard' = 'Vanguard'
    'state-street' = 'State Street'
    'fidelity' = 'Fidelity Investments'
    'google' = 'Google'
    'amazon' = 'Amazon'
    'apple' = 'Apple'
    'microsoft' = 'Microsoft'
    'nvidia' = 'NVIDIA'
    'tesla' = 'Tesla'
    'spotify' = 'Spotify'
    'stripe' = 'Stripe'
    'bloomberg' = 'Bloomberg'
    'kdb' = 'KDB+'
    'databricks' = 'Databricks'
    'palantir' = 'Palantir'
}

$fixCount = 0
$alreadyGood = 0

for ($i = 0; $i -lt $companies.Count; $i++) {
    $c = $companies[$i]
    $id = $c.id
    $name = $c.name

    # Check if corrupted (contains .Groups[1])
    $isCorrupted = $name -match 'Groups\[1\]'

    if ($isCorrupted) {
        if ($overrides.ContainsKey($id)) {
            $newName = $overrides[$id]
        } else {
            # Generate from id: title case each word
            $words = $id -split '-'
            $titleWords = @()
            foreach ($w in $words) {
                if ($w.Length -le 1) {
                    $titleWords += $w.ToUpper()
                } else {
                    $titleWords += $w.Substring(0,1).ToUpper() + $w.Substring(1)
                }
            }
            $newName = $titleWords -join ' '
        }
        $companies[$i].name = $newName
        $fixCount++
        [Console]::Out.WriteLine("  Fixed: $id -> $newName")
    } else {
        # Also check for known overrides on non-corrupted entries
        if ($overrides.ContainsKey($id) -and $name -ne $overrides[$id]) {
            # Only override if the current name looks auto-generated (e.g., "Transmarket Group" -> "TransMarket Group")
            $autoGen = ($id -replace '-', ' ') -replace '(?<=\s|^)(\w)', { param($m); $m.Groups[1].Value.ToUpper() }
            # Skip - don't override manually curated names
        }
        $alreadyGood++
    }
}

[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("Fixed $fixCount corrupted names, $alreadyGood already good")
[Console]::Out.WriteLine("Total companies: $($companies.Count)")

# Save
$companies | ConvertTo-Json -Depth 5 | Set-Content $companiesPath -Encoding UTF8
$size = [math]::Round((Get-Item $companiesPath).Length / 1KB, 1)
[Console]::Out.WriteLine("Saved. File size: ${size} KB")
