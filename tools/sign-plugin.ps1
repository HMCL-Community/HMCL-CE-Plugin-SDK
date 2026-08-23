param(
    [Parameter(Mandatory = $true)][string]$Manifest,
    [Parameter(Mandatory = $true)][string]$Output,
    [string]$Package,
    [string]$PackageUrl,
    [string]$Version,
    [switch]$Community
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)

if (-not [string]::IsNullOrWhiteSpace($env:HMCLCE_PLUGIN_SIGNING_KEY) -or
    -not [string]::IsNullOrWhiteSpace($env:HMCLCE_PLUGIN_CERTIFICATE)) {
    throw 'Developer-held certification keys are no longer supported. Remove HMCLCE_PLUGIN_SIGNING_KEY and HMCLCE_PLUGIN_CERTIFICATE, then use request-certification.ps1 with GitHub Actions OIDC.'
}

$document = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$documentProperties = @($document.PSObject.Properties.Name)
if ($documentProperties -contains 'signed' -or $documentProperties -contains 'signatures' -or
    $documentProperties -contains 'certificate') {
    throw 'Input manifest must be an unsigned schemaVersion 2 payload.'
}
if ([int]$document.schemaVersion -ne 2) {
    throw 'HMCL CE publishing requires a schemaVersion 2 store manifest.'
}

if (-not [string]::IsNullOrWhiteSpace($Package)) {
    if ([string]::IsNullOrWhiteSpace($Version) -or [string]::IsNullOrWhiteSpace($PackageUrl)) {
        throw '-Version and -PackageUrl are required when -Package is supplied.'
    }
    $resolvedPackage = (Resolve-Path -LiteralPath $Package).Path
    $release = @($document.versions | Where-Object { [string]$_.version -ceq $Version })
    if ($release.Count -ne 1) {
        throw "Manifest must contain exactly one versions[] entry for $Version."
    }
    $release[0].packageUrl = $PackageUrl
    $release[0].sha256 = (Get-FileHash -LiteralPath $resolvedPackage -Algorithm SHA256).Hash.ToLowerInvariant()
    $release[0].size = (Get-Item -LiteralPath $resolvedPackage).Length
    if ($release[0].PSObject.Properties.Name -contains 'certification') {
        $release[0].PSObject.Properties.Remove('certification')
    }
}

$parent = Split-Path -Parent ([System.IO.Path]::GetFullPath($Output))
if (-not [string]::IsNullOrWhiteSpace($parent)) {
    [void](New-Item -ItemType Directory -Path $parent -Force)
}
[System.IO.File]::WriteAllText(
    [System.IO.Path]::GetFullPath($Output),
    (($document | ConvertTo-Json -Depth 100) + "`n"),
    $utf8
)

Write-Host "Wrote unsigned manifest candidate: $Output"
if ($Community) {
    Write-Host 'Community mode selected; this manifest intentionally contains no certification proof.'
} else {
    Write-Host 'To obtain certification, submit the exact NPL through request-certification.ps1. A repository approval alone cannot certify this version.'
}
