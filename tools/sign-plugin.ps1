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
    throw 'Developer-held certification keys are no longer supported. Remove HMCLCE_PLUGIN_SIGNING_KEY and HMCLCE_PLUGIN_CERTIFICATE.'
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
    Write-Host 'Community manifest generated; packageUrl, SHA-256 and size are bound to this exact NPL.'
} else {
    Write-Host 'Official-store listing is maintained in the HMCL-CE-Plugin-Store repository; it is a source label, not an install requirement.'
}
