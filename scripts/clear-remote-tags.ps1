# Clear Remote tags in repository
# Requires GitHub Token (with 'repo' scope) to delete .
    [string]$Token = $env:GITHUB_TOKEN,
    [string]$Repo = 'djaus2/HelloWo4rldWPFApp',
    [switch]$DryRun
)

if (-not $Token) {
    Write-Error "GitHub token is required. Pass -Token or set GITHUB_TOKEN in the environment."
    exit 1
}

$apiBase = "https://api.github.com/repos/$Repo"
$hdr = @{ Authorization = "token $Token"; 'User-Agent' = 'delete-script' }

# List refs/tags
try {
    $refs = Invoke-RestMethod -Uri "$apiBase/git/refs/tags" -Headers $hdr -Method Get
} catch {
    Write-Error "Failed to list tag refs: $($_)"
    exit 1
}

if (-not $refs -or $refs.Count -eq 0) {
    Write-Host "No remote tag refs found for $Repo."
    exit 0
}

foreach ($r in $refs) {
    $tag = $r.ref -replace '^refs/tags/',''
    if ($DryRun) {
        Write-Host "DRY RUN: would delete remote tag $tag via API..."
        continue
    }

    Write-Host "Deleting remote tag $tag via API..."
    try {
        Invoke-RestMethod -Uri "$apiBase/git/refs/tags/$([uri]::EscapeDataString($tag))" -Headers $hdr -Method Delete
    } catch {
        Write-Warning "Failed to delete tag $tag: $($_)"
    }
}

Write-Host "Done."
