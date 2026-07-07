# Disable release creation in .github/workflows/release.yml by commenting out blocks.
# Creates a backup at .github/workflows/release.yml.bak.disable and commits + pushes the workflow change.

$path = ".github\workflows\release.yml"
$bak  = "$path.bak.disable"

if (-not (Test-Path $path)) {
    Write-Error "Workflow file not found at $path"
    exit 1
}

if (-not (Test-Path $bak)) {
    Copy-Item -Path $path -Destination $bak -Force
    Write-Host "Backup created: $bak"
} else {
    Write-Host "Backup already exists: $bak"
}

$lines = Get-Content -Path $path
$out = New-Object System.Collections.Generic.List[string]

$inDispatch = $false
$inTags = $false
$inReleaseStep = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    # If currently in a commented block, check for exit conditions first.
    if ($inDispatch) {
        if ($line -match '^\S') {
            $inDispatch = $false
            # fall through to normal processing of this line
        } else {
            $out.Add("# $line")
            continue
        }
    }

    if ($inTags) {
        if ($line -match '^\s*-\s*') {
            $out.Add("# $line")
            continue
        } else {
            $inTags = $false
            # fall through to normal processing
        }
    }

    if ($inReleaseStep) {
        # end the release-step block when we see the next step at same step-indent level
        if ($line -match '^\s{4}-\s*name:' -and -not ($line -match '^\s{4}-\s*name:\s*Create GitHub Release')) {
            $inReleaseStep = $false
            # fall through to normal processing so the next step remains uncommented
        } else {
            $out.Add("# $line")
            continue
        }
    }

    # Detect starts of blocks to comment
    if ($line -match '^\s*workflow_dispatch:') {
        $inDispatch = $true
        $out.Add("# $line")
        continue
    }

    if ($line -match '^\s*tags:\s*$') {
        # Comment the tags: line and its list entries
        $inTags = $true
        $out.Add("# $line")
        continue
    }

    if ($line -match '^\s{4}-\s*name:\s*Create GitHub Release') {
        $inReleaseStep = $true
        $out.Add("# $line")
        continue
    }

    # Default: copy line unchanged
    $out.Add($line)
}

# Write back (preserve UTF8)
$out | Set-Content -Path $path -Encoding UTF8
Write-Host "Disabled release-creation blocks in $path"

#
# Git commit & push the single workflow change (do NOT add the backup file)
#
# Requirements: git installed and configured. Script will report and exit non-zero on failures.
#

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Warning "git not found in PATH — skipping commit/push."
    exit 0
}

# Ensure we're inside a git repo
$repoRoot = & git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Not inside a git repository — skipping commit/push."
    exit 0
}

# Stage only the workflow file
& git add -- "$path"
if ($LASTEXITCODE -ne 0) {
    Write-Error "git add failed for $path"
    exit 1
}

# Check if there is anything to commit for that path
$status = & git status --porcelain -- "$path"
if (-not $status) {
    Write-Host "No changes to commit for $path."
    exit 0
}

# Commit
$timestamp = (Get-Date).ToString("s")
$commitMsg = "chore(release): disable release workflow (automated) [$timestamp]"
& git commit -m $commitMsg -- "$path"
if ($LASTEXITCODE -ne 0) {
    Write-Error "git commit failed."
    exit 1
}

# Determine current branch and push
$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
if (-not $branch) {
    Write-Error "Unable to determine current branch. Commit created locally but cannot push."
    exit 1
}

Write-Host "Pushing commit to origin/$branch..."
& git push origin $branch
if ($LASTEXITCODE -ne 0) {
    Write-Error "git push failed. Commit exists locally."
    exit 1
}

Write-Host "Workflow disabled and change pushed to origin/$branch."