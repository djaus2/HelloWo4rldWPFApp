# Create a new Release, auto incremented
param(
    [string]$version,
    [switch]$DispatchWorkflow,
    [string]$AppName = 'HelloWo4rldWPFApp',
    [string]$WorkflowFile = '.github/workflows/release.yml',
    [string]$WorkflowRef = 'main',
    [switch]$AllowCachedAuth  # opt-in to allow cached credentials
)

$versionFile = ".version"

# ✅ Function: Increment patch version
function Increment-Version($ver) {
    if ($ver -match "^v(\d+)\.(\d+)\.(\d+)$") {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        $patch = [int]$Matches[3]

        $patch++

        return "v$major.$minor.$patch"
    } else {
        Write-Error "Invalid version format. Expected vX.Y.Z"
        exit 1
    }
}

# ✅ Step 1: Determine version
if ($version) {
    Write-Host "Using provided version: $version"
}
else {
    if (Test-Path $versionFile) {
        $lastVersion = (Get-Content $versionFile -Raw).Trim()
        Write-Host "Last version found: $lastVersion"

        $version = Increment-Version $lastVersion
        Write-Host "Auto-incremented version: $version"
    }
    else {
        $version = "v1.0.0"
        Write-Host "No version file found. Starting at $version"
    }
}

# ✅ Step 2..4: Create a unique tag and push it
# If the tag exists locally or on the remote, auto-increment and retry.
$maxAttempts = 20
$attempt = 0
$remoteName = "origin"

while ($attempt -lt $maxAttempts) {
    $attempt++

    # ensure local tag doesn't already exist
    $localExisting = git tag --list $version
    if ($localExisting) {
        Write-Host "Local tag $version already exists — incrementing..."
        $version = Increment-Version $version
        continue
    }

    # check remote for existing tag
    $remoteExisting = git ls-remote --tags $remoteName "refs/tags/$version" 2>$null
    if ($remoteExisting) {
        Write-Host "Remote already has tag $version — auto-incrementing..."
        $version = Increment-Version $version
        continue
    }

    # create local tag
    Write-Host "Creating tag $version..."
    git tag $version

    # save tentative version to file (only after tag created locally)
    Set-Content $versionFile $version

    # attempt to push
    Write-Host "Pushing tag to $remoteName..."
    git push $remoteName $version
    $exit = $LASTEXITCODE

    if ($exit -eq 0) {
        Write-Host "✅ Release triggered for $version"
        # persist version only after successful push
        Set-Content $versionFile $version

        if ($DispatchWorkflow) {
            $gh = Get-Command gh -ErrorAction SilentlyContinue
            if (-not $gh) {
                Write-Warning "Cannot dispatch workflow: GitHub CLI 'gh' not found. Install and run 'gh auth login' to enable dispatch."
            } else {
                Write-Host "Dispatching workflow $WorkflowFile (ref $WorkflowRef) with app_name='$AppName'..."
                & gh workflow run $WorkflowFile --ref $WorkflowRef -f app_name="$AppName"
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "gh workflow run failed with exit code $LASTEXITCODE"
                } else {
                    Write-Host "Dispatched workflow successfully."
                }
            }
        }

        exit 0
    }

    # push failed — remove local tag and retry
    Write-Warning "Failed to push tag $version (exit code $exit). Removing local tag and retrying..."
    git tag -d $version 2>$null

    # if remote now has the tag (race), increment and retry
    $remoteExistingNow = git ls-remote --tags $remoteName "refs/tags/$version" 2>$null
    if ($remoteExistingNow) {
        $version = Increment-Version $version
        continue
    }

    # otherwise give up with error
    Write-Error "Failed to push tag $version and remote does not report the tag. Aborting."
    exit 1
}

Write-Error "Exceeded maximum attempts ($maxAttempts) trying to find a unique version tag. Aborting."
exit 1

function Require-NoCachedAuth {
  if ($AllowCachedAuth) { return }

  # 1) gh logged in?
  $gh = Get-Command gh -ErrorAction SilentlyContinue
  if ($gh) {
    try { gh auth status -t > $null 2>&1; if ($LASTEXITCODE -eq 0) { Write-Error 'gh is logged in — clear gh auth or pass -AllowCachedAuth to proceed.'; exit 1 } } catch {}
  }

  # 2) credential helper configured? assume it may cache creds
  $credHelper = git config --get credential.helper 2>$null
  if ($credHelper) {
    Write-Error "Git credential helper '$credHelper' is configured — cached credentials may exist. Clear them or run with -AllowCachedAuth."
    exit 1
  }

  # 3) SSH agent keys present
  try {
    $sshOut = & ssh-add -l 2>$null
    if ($sshOut -and $sshOut -notmatch 'The agent has no identities') {
      Write-Error "SSH agent has loaded keys. Clear with 'ssh-add -D' or run with -AllowCachedAuth."
      exit 1
    }
  } catch { }
}

Require-NoCachedAuth
