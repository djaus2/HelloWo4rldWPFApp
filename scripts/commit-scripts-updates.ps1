<#
Commit and optionally push updated scripts.
Usage:
  # Commit + push (default)
  .\scripts\commit-scripts-updates.ps1 -Files scripts\clear-remote-tags.ps1,scripts\clean-release-tags.ps1
  # Commit only (no push)
  .\scripts\commit-scripts-updates.ps1 -Files scripts\clear-remote-tags.ps1 -NoPush
#>
param(
    [string[]] $Files,
    [switch] $NoPush
)

if (-not $Files -or $Files.Count -eq 0) {
    Write-Error "Specify files to commit via -Files"
    exit 1
}

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Error "git not found in PATH — cannot commit."
    exit 1
}

# Ensure inside git repo
if (& git rev-parse --show-toplevel 2>$null -eq $null) {
    Write-Error "Not inside a git repo."
    exit 1
}

# Stage only the specified files
foreach ($f in $Files) {
    if (-not (Test-Path $f)) {
        Write-Warning "File not found: $f — skipping."
        continue
    }
    & git add -- "$f"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git add failed for $f"
        exit 1
    }
}

# Check for changes
$status = & git status --porcelain
if (-not $status) {
    Write-Host "No changes to commit."
    exit 0
}

$timestamp = (Get-Date).ToString("s")
$commitMsg = "chore(release): update scripts (automated) [$timestamp] - $($Files -join ', ')"
& git commit -m $commitMsg
if ($LASTEXITCODE -ne 0) {
    Write-Error "git commit failed."
    exit 1
}

if (-not $NoPush) {
    $branch = (& git rev-parse --abbrev-ref HEAD).Trim()
    if (-not $branch) {
        Write-Warning "Unable to determine branch; commit created locally."
        exit 0
    }
    Write-Host "Pushing commit to origin/$branch..."
    & git push origin $branch
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git push failed. Commit exists locally."
        exit 1
    }
    Write-Host "Committed and pushed."
} else {
    Write-Host "Committed locally; push skipped due to -NoPush."
}