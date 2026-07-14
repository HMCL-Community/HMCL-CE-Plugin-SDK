# Publish a plugin package to a GitHub release and update manifest.json manually.
# Usage:
#   ./publish-plugin.ps1 -Repo owner/repo -Tag v1.0.0 -Package path/to/plugin.npl
param(
    [Parameter(Mandatory=$true)][string]$Repo,
    [Parameter(Mandatory=$true)][string]$Tag,
    [Parameter(Mandatory=$true)][string]$Package
)
$ErrorActionPreference = 'Stop'
$hash = (Get-FileHash -Path $Package -Algorithm SHA256).Hash.ToLowerInvariant()
$name = Split-Path -Leaf $Package

gh release create $Tag $Package --repo $Repo --title $Tag --notes "Release $Tag"

Write-Host "Package URL: https://github.com/$Repo/releases/download/$Tag/$name"
Write-Host "SHA-256: $hash"
Write-Host "Add these values to manifest.json and update plugin store plugins.json."
