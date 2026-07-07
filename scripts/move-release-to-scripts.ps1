<#
Move root-level release.ps1 into scripts\ and commit + push the change.
This is safe: it will bail if target exists. Requires git configured.
#>

$src = "release.ps1"
$dstDir = "scripts"
$dst = Join-Path $dstDir "release.ps1"

if (-not (Test-Path $src)) {
    Write-Error "Source file not found: $src"
    exit 1
}

if (-not (Test-Path $dstDir)) {
    New-Item -ItemType Directory -Path $dstDir | Out-Null
    Write-Host "Created directory: $dstDir"
}

if (Test-Path $dst) {
    Write-Error "Destination file already exists: $dst. Aborting to avoid overwrite."
    exit 1
}

# Move file
Move-Item -Path $src -Destination $dst
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to move file."
    exit 1
}
Write-Host "Moved $src -> $dst"

# Git commit & push
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Warning "git not found in PATH — moved file but skipping commit/push."
    exit 0
}

# Stage move (git will detect rename)
& git add -- "$src" "$dst"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "git add failed; you may need to run 'git add' manually."
    exit 1
}

$status = & git status --porcelain -- "$dst"
if (-not $status) {
    Write-Host "No changes to commit for $dst."
    exit 0
}

$timestamp = (Get-Date).ToString("s")
$commitMsg = "chore(release): move release.ps1 into scripts/ (automated) [$timestamp]"
& git commit -m $commitMsg -- "$src" "$dst"
if ($LASTEXITCODE -ne 0) {
    Write-Error "git commit failed. Move applied locally."
    exit 1
}

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

Write-Host "Move committed and pushed to origin/$branch."