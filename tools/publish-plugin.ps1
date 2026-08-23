# Publish an unsigned community plugin package to a GitHub release.
# Usage:
#   ./publish-plugin.ps1 -Repo owner/repo -Tag v1.0.0 -Package plugin.npl -Manifest manifest.template.json -Community
param(
    [Parameter(Mandatory=$true)][string]$Repo,
    [Parameter(Mandatory=$true)][string]$Tag,
    [Parameter(Mandatory=$true)][string]$Package,
    [Parameter(Mandatory=$true)][string]$Manifest,
    [string]$OutputManifest = (Join-Path (Get-Location) 'manifest.json'),
    [switch]$Community
)
$ErrorActionPreference = 'Stop'
if (-not $Community) {
    throw 'Certified releases require the GitHub Actions OIDC workflow. Use store/github-release-workflow.yml; local developer keys cannot grant HMCL CE certification.'
}
if (-not [string]::IsNullOrWhiteSpace($env:HMCLCE_PLUGIN_SIGNING_KEY) -or
    -not [string]::IsNullOrWhiteSpace($env:HMCLCE_PLUGIN_CERTIFICATE)) {
    throw 'Remove legacy HMCLCE_PLUGIN_SIGNING_KEY and HMCLCE_PLUGIN_CERTIFICATE values. They are not accepted by the current certification service.'
}
$hash = (Get-FileHash -Path $Package -Algorithm SHA256).Hash.ToLowerInvariant()
$name = Split-Path -Leaf $Package
$version = $Tag -replace '^v', ''
$packageUrl = "https://github.com/$Repo/releases/download/$Tag/$name"
$arguments = @{
    Manifest = $Manifest
    Output = $OutputManifest
    Package = $Package
    PackageUrl = $packageUrl
    Version = $version
    Community = $true
}
& (Join-Path $PSScriptRoot 'sign-plugin.ps1') @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Manifest generation failed with exit code $LASTEXITCODE."
}
gh release create $Tag $Package $OutputManifest --repo $Repo --title $Tag --notes "Release $Tag"
if ($LASTEXITCODE -ne 0) {
    throw "GitHub release creation failed with exit code $LASTEXITCODE."
}

Write-Host "Package URL: $packageUrl"
Write-Host "SHA-256: $hash"
Write-Host "Generated manifest: $OutputManifest"
Write-Host 'Commit this exact file as manifest.json on the repository default branch.'
