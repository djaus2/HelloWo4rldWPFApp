# Restore original workflow file from the backup created by disable script and commit + push the change.

$path = ".github\workflows\release.yml"
$bak  = "$path.bak.disable"

if (-not (Test-Path $bak)) {
    Write-Error "Backup not found: $bak. Cannot restore."
    exit 1
}

Copy-Item -Path $bak -Destination $path -Force
Remove-Item -Path $bak -Force
Write-Host "Restored $path from backup and removed backup: $bak"

#
# Git commit & push the single workflow change (do NOT add the backup file)
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
$commitMsg = "chore(release): enable release workflow (automated) [$timestamp]"
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

Write-Host "Workflow restored and change pushed to origin/$branch."