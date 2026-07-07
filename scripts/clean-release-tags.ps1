# Clears local tags and remote tags and releases.
# Requires GitHub Token (with 'repo' scope) to delete releases.
param(
    [switch]$Force,
    [switch]$DryRun,
    [string]$Remote = "origin",
    [string]$Token = $env:GITHUB_TOKEN,
    [switch]$IncludeRemoteOnly
)

function Fail($msg){ Write-Error $msg; exit 1 }

# remember whether a token was passed explicitly and original env value
$origEnvGitHubToken = $env:GITHUB_TOKEN
$passedToken = $null
if ($PSBoundParameters.ContainsKey('Token')) { $passedToken = $Token }

# get local tags
$tagsRaw = git tag --list 2>$null
$tagList = if ($tagsRaw) { $tagsRaw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } } else { @() }

# get remote tags (may include tags not present locally)
$remoteTagsRaw = git ls-remote --tags $Remote 2>$null
$remoteTagList = @()
if ($remoteTagsRaw) {
    $remoteTagsRaw -split "`n" | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '') { return }
        $parts = $line -split "\s+"
        if ($parts.Length -ge 2) {
            $ref = $parts[1]
            if ($ref -match 'refs/tags/(.+?)(\^\{\})?$') {
                $remoteTagList += $Matches[1]
            }
        }
    }
}
$remoteTagList = $remoteTagList | Select-Object -Unique

# get remote url and owner/repo
$remoteUrl = git remote get-url $Remote 2>$null
if (-not $remoteUrl) { Fail "Unable to get remote '$Remote' url." }

# parse owner/repo
if ($remoteUrl -match "github\.com[:/](.+?)(?:\.git)?$") {
    $ownerRepo = $Matches[1]
} else {
    Fail "Remote url '$remoteUrl' doesn't look like a GitHub URL."
}

Write-Host "Repository: $ownerRepo"
Write-Host "Local tags: $($tagList.Count). Remote tags: $($remoteTagList.Count)."

if ($DryRun) {
    Write-Host "DRY RUN: Listing tags and releases (no deletion)."
}

# prepare remote delete list
$remoteDeleteList = @()
if ($IncludeRemoteOnly) {
    $remoteDeleteList = ($tagList + $remoteTagList) | Select-Object -Unique
} else {
    $remoteDeleteList = $tagList
}

if (-not $Force -and -not $DryRun) {
    $msg = "Type 'YES' to confirm deletion of tags and releases in $ownerRepo"
    if ($IncludeRemoteOnly) { $msg = $msg + " (including remote-only tags)" }
    $confirm = Read-Host $msg
    if ($confirm -ne "YES") { Write-Host "Aborted by user."; exit 0 }
}

# Delete local tags
foreach ($t in $tagList) {
    if ($DryRun) {
        Write-Host "DRY RUN: would delete local tag '$t'"
    } else {
        Write-Host "Deleting local tag '$t'..."
        git tag -d $t 2>$null
    }
}

# Delete remote tags (git push --delete)
foreach ($t in $remoteDeleteList) {
    if ($DryRun) {
        Write-Host "DRY RUN: would delete remote tag '$t' from '$Remote'"
    } else {
        Write-Host "Deleting remote tag '$t' from '$Remote'..."
        git push $Remote --delete $t 2>$null
        if ($LASTEXITCODE -ne 0) {
            # fallback to ref syntax
            git push $Remote :refs/tags/$t 2>$null
        }
    }
}

# Delete GitHub Releases via API (optional)
$skipReleases = $false
if (-not $Token) {
    Write-Warning "No GitHub token provided. Skipping deletion of GitHub Releases. To delete releases, set GITHUB_TOKEN or pass -Token <PAT> (needs 'repo' scope)."
    $skipReleases = $true
}

if (-not $skipReleases) {
    $apiBase = "https://api.github.com/repos/$ownerRepo"

    Write-Host "Fetching releases from GitHub..."
    $headers = @{ "User-Agent" = "delete-all-tags-and-releases-script" }
    if ($Token) { $headers["Authorization"] = "token $Token" }

    # Fetch all releases with pagination
    $releases = @()
    $page = 1
    try {
        while ($true) {
            $uri = "$apiBase/releases?per_page=100&page=$page"
            $batch = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            if (-not $batch -or $batch.Count -eq 0) { break }
            $releases += $batch
            if ($batch.Count -lt 100) { break }
            $page++
        }
    } catch {
        Fail ("Failed to fetch releases: $($_)")
    }

    if (-not $releases -or $releases.Count -eq 0) {
        Write-Host "No releases found."
    } else {
        Write-Host "Found $($releases.Count) release(s)."
        foreach ($r in $releases) {
            $rid = $r.id
            $tag = $r.tag_name
            if ($DryRun) {
                Write-Host "DRY RUN: would delete release id=$rid tag='$tag'"
                continue
            }

            Write-Host "Deleting release id=$rid tag='$tag'..."

            # Delete release assets first to avoid orphaned objects
            try {
                $assets = Invoke-RestMethod -Uri "$apiBase/releases/$rid/assets?per_page=100" -Headers $headers -Method Get
                if ($assets) {
                    foreach ($a in $assets) {
                        $aid = $a.id
                        Write-Host "  Deleting asset id=$aid name='$($a.name)'..."
                        try {
                            Invoke-RestMethod -Uri "$apiBase/releases/assets/$aid" -Headers $headers -Method Delete
                        } catch {
                            Write-Warning ("  Failed to delete asset id=$($aid): $($_)")
                        }
                    }
                }
            } catch {
                Write-Warning ("  Failed to list assets for release id=$($rid): $($_)")
            }

            # Delete the release
            try {
                Invoke-RestMethod -Uri "$apiBase/releases/$rid" -Headers $headers -Method Delete
            } catch {
                Write-Warning ("Failed to delete release id=$($rid): $($_)")
                continue
            }

            # also delete tag ref on GitHub via API (we already attempted git push deletion)
            if ($tag) {
                $refUri = "$apiBase/git/refs/tags/$([uri]::EscapeDataString($tag))"
                try {
                    Invoke-RestMethod -Uri $refUri -Headers $headers -Method Delete
                    Write-Host "Deleted git ref for tag '$tag' via API."
                } catch {
                    # ignore failure (may already be gone)
                }
            }
        }
    }
} else {
    Write-Host "Skipping GitHub release deletion."
}

# clear token from process environment if it was passed as parameter and the env var matches
if ($passedToken -ne $null) {
    try {
        if ($env:GITHUB_TOKEN -and $env:GITHUB_TOKEN -eq $passedToken) {
            Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
            Write-Host "Cleared GITHUB_TOKEN from environment (session)."
        }
    } catch {
        # ignore
    }
    # also clear local variable
    $Token = $null
}

Write-Host "Done."
