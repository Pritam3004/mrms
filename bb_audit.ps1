# Bitbucket commit audit for MRMS UAT items — all repos
$envFile = "$PSScriptRoot\.jira.env"
$repos = @(
    @{ Name = "section2";          Slug = "section2";           TokenKey = "BITBUCKET_TOKEN_Section2" },
    @{ Name = "MandateDashboard";  Slug = "mandatedashboard";   TokenKey = "BITBUCKET_TOKEN_MandateDashboard" },
    @{ Name = "OSPython";          Slug = "ospython";           TokenKey = "BITBUCKET_TOKEN_OSPython" }
)

# UAT items to cross-check (key -> keywords from title)
$uatItems = @{
    "MRMS-1694" = @("included in reporting", "adoption status")
    "MRMS-1734" = @("SR mandate", "mandate table", "does not save")
    "MRMS-1774" = @("revised estimates report", "auto-generated", "template")
    "MRMS-2144" = @("duplicate names", "page 1", "oral statement")
    "MRMS-2145" = @("duplicative text", "oral statement")
    "MRMS-2154" = @("not reviewed", "revest", "revised estimate")
    "MRMS-2155" = @("navigate", "reviewed resolutions", "revest")
    "MRMS-2161" = @("attachments", "bulk amendment")
    "MRMS-2173" = @("revised estimate", "disabled", "does not load")
    "MRMS-2174" = @("duplicate", "fast click", "button click")
    "MRMS-2178" = @("documentation")
    "MRMS-2215" = @("summary table", "500", "sharepoint", "threshold", "loading")
    "MRMS-2233" = @("accompanying staff", "associate items", "rev est")
    "MRMS-2234" = @("bulk amendment", "parsed", "parse")
    "MRMS-2337" = @("authentication", "auth")
    "MRMS-2377" = @("reduction amounts", "current year", "oral statement")
    "MRMS-2382" = @("accessibility", "sect 2", "29e")
    "MRMS-2383" = @("orals", "cover page")
    "MRMS-2565" = @("os entries", "status list", "resolution", "mandates")
    "MRMS-2582" = @("misc form", "loading indefinitely", "keeps loading")
}

# --- Step 1: Fetch commits from all repos ---
# For each Jira key, find the first matching commit across all repos
$bestMatch = @{}

foreach ($repo in $repos) {
    $tokenLine = Get-Content $envFile | Select-String $repo.TokenKey
    if (-not $tokenLine) {
        Write-Host "SKIP $($repo.Name) — token '$($repo.TokenKey)' not found in .jira.env" -ForegroundColor Yellow
        continue
    }
    $token = $tokenLine.ToString().Split("=",2)[1].Trim()
    $headers = @{ Authorization = "Bearer $token" }

    Write-Host "Fetching $($repo.Name) (iccgit/$($repo.Slug)) master..." -ForegroundColor Cyan
    $allCommits = @()
    $url = "https://api.bitbucket.org/2.0/repositories/iccgit/$($repo.Slug)/commits?include=master&pagelen=100&fields=values.hash,values.message,values.date,next"

    do {
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
            $allCommits += $response.values
            $url = $response.next
        } catch {
            Write-Host "  ERROR on $($repo.Name): $($_.Exception.Message)" -ForegroundColor Red
            $url = $null
        }
    } while ($url -and $allCommits.Count -lt 500)

    Write-Host "  $($allCommits.Count) commits fetched" -ForegroundColor Gray

    # Cross-reference each UAT item against this repo's commits
    foreach ($key in $uatItems.Keys) {
        if ($bestMatch.ContainsKey($key)) { continue }  # already found in a previous repo

        $matched = $allCommits | Where-Object { $_.message -match $key } | Select-Object -First 1

        if (-not $matched) {
            foreach ($kw in $uatItems[$key]) {
                $matched = $allCommits | Where-Object { $_.message -imatch [regex]::Escape($kw) } | Select-Object -First 1
                if ($matched) { break }
            }
        }

        if ($matched) {
            $bestMatch[$key] = @{
                Repo = $repo.Name
                Date = ([datetime]$matched.date).ToString("yyyy-MM-dd")
                Msg  = if ($matched.message.Split("`n")[0].Length -gt 44) { $matched.message.Split("`n")[0].Substring(0,41) + "..." } else { $matched.message.Split("`n")[0] }
                Hash = $matched.hash.Substring(0,7)
            }
        }
    }
}

# --- Step 2: Print combined results ---
Write-Host ""
Write-Host "=== MRMS UAT Deployment Audit — All Repos ===" -ForegroundColor Yellow
Write-Host ("{0,-12} {1,-5} {2,-18} {3,-12} {4,-44} {5}" -f "Jira Key","Found","Repo","Date","Commit Msg","Hash") -ForegroundColor White
Write-Host ("-" * 110)

$confirmed = @()
$notFound  = @()

foreach ($key in ($uatItems.Keys | Sort-Object)) {
    if ($bestMatch.ContainsKey($key)) {
        $m = $bestMatch[$key]
        Write-Host ("{0,-12} {1,-5} {2,-18} {3,-12} {4,-44} {5}" -f $key, "YES", $m.Repo, $m.Date, $m.Msg, $m.Hash) -ForegroundColor Green
        $confirmed += $key
    } else {
        Write-Host ("{0,-12} {1,-5} {2}" -f $key, "NO", "— not found in any repo master branch") -ForegroundColor Red
        $notFound += $key
    }
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Yellow
Write-Host "Confirmed in master : $($confirmed.Count) items  -> Safe to send to Alex for UAT" -ForegroundColor Green
Write-Host "NOT found in master : $($notFound.Count) items  -> Investigate before sending to Alex" -ForegroundColor Red

if ($notFound.Count -gt 0) {
    Write-Host ""
    Write-Host "Items to investigate:" -ForegroundColor Red
    $notFound | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}

Write-Host ""
Write-Host "NOTE: Keyword-matched items (no Jira key in commit) should be verified manually." -ForegroundColor Gray
