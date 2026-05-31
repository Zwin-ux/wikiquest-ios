param(
  [Parameter(Mandatory = $true)]
  [string]$Repository,

  [Parameter(Mandatory = $true)]
  [string]$KeyId,

  [Parameter(Mandatory = $true)]
  [string]$IssuerId,

  [Parameter(Mandatory = $true)]
  [string]$KeyPath
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw "GitHub CLI is required. Install gh and authenticate with repo/admin access first."
}

if (-not (Test-Path -LiteralPath $KeyPath)) {
  throw "App Store Connect key file was not found: $KeyPath"
}

gh repo view $Repository *> $null
if ($LASTEXITCODE -ne 0) {
  throw "GitHub CLI cannot access $Repository. Re-authenticate with a token that can manage Actions secrets."
}

gh secret set ASC_KEY_ID -R $Repository --body $KeyId
gh secret set ASC_ISSUER_ID -R $Repository --body $IssuerId
$keyBytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $KeyPath))
$keyBase64 = [Convert]::ToBase64String($keyBytes)
gh secret set ASC_API_KEY_P8_BASE64 -R $Repository --body $keyBase64

Write-Host "Stored ASC_KEY_ID, ASC_ISSUER_ID, and ASC_API_KEY_P8_BASE64 for $Repository."
