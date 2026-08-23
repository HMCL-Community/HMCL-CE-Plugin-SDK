$ErrorActionPreference = 'Stop'

function Assert-Condition([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Fails([scriptblock]$Action, [string]$ExpectedMessage) {
    try {
        & $Action
    } catch {
        Assert-Condition ($_.Exception.Message -like "*$ExpectedMessage*") "Expected '$ExpectedMessage', got '$($_.Exception.Message)'"
        return
    }
    throw "Expected failure containing '$ExpectedMessage'"
}

$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ('hmclce-publishing-tools-test-' + [guid]::NewGuid())
[void](New-Item -ItemType Directory -Path $temporary)
$previousSigningKey = $env:HMCLCE_PLUGIN_SIGNING_KEY
$previousCertificate = $env:HMCLCE_PLUGIN_CERTIFICATE
try {
    $env:HMCLCE_PLUGIN_SIGNING_KEY = $null
    $env:HMCLCE_PLUGIN_CERTIFICATE = $null
    $package = Join-Path $temporary 'fixture.npl'
    [System.IO.File]::WriteAllBytes($package, [byte[]](0..255))
    $manifest = Join-Path $temporary 'manifest.template.json'
    [System.IO.File]::WriteAllText(
        $manifest,
        (@{
            schemaVersion = 2
            id = 'dev.hmclce.fixture'
            repository = 'github.com/owner/repo'
            versions = @(@{
                version = '1.0.0'
                packageUrl = 'https://invalid.example/placeholder.npl'
                sha256 = '0' * 64
                size = 1
            })
        } | ConvertTo-Json -Depth 10),
        [System.Text.UTF8Encoding]::new($false)
    )
    $output = Join-Path $temporary 'manifest.json'
    & (Join-Path $PSScriptRoot 'sign-plugin.ps1') `
        -Manifest $manifest `
        -Output $output `
        -Package $package `
        -PackageUrl 'https://github.com/owner/repo/releases/download/v1.0.0/fixture.npl' `
        -Version '1.0.0' `
        -Community
    $generated = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
    $expectedHash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-Condition ([string]$generated.versions[0].sha256 -ceq $expectedHash) 'Manifest generator did not bind the local package SHA-256.'
    Assert-Condition ([int64]$generated.versions[0].size -eq 256) 'Manifest generator did not bind the local package size.'
    Assert-Condition ($null -eq $generated.versions[0].certification) 'Unsigned manifest generator retained certification data.'

    $env:HMCLCE_PLUGIN_SIGNING_KEY = 'legacy-key'
    Assert-Fails {
        & (Join-Path $PSScriptRoot 'sign-plugin.ps1') -Manifest $manifest -Output $output -Community
    } 'Developer-held certification keys are no longer supported'
    $env:HMCLCE_PLUGIN_SIGNING_KEY = $null


    $workflow = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\store\github-release-workflow.yml') -Raw
    $manifestPublishStep = $workflow.IndexOf('- name: Publish manifest on the default branch', [System.StringComparison]::Ordinal)
    $releasePublishStep = $workflow.IndexOf('- name: Publish release', [System.StringComparison]::Ordinal)
    Assert-Condition ($manifestPublishStep -ge 0 -and $releasePublishStep -gt $manifestPublishStep) 'Certified workflow must publish the default-branch manifest before making the draft Release public.'
    Assert-Condition ($workflow.IndexOf('id-token', [System.StringComparison]::Ordinal) -lt 0) 'Community workflow must not require the GitHub OIDC permission.'
    Assert-Condition ($workflow.IndexOf('request-certification.ps1', [System.StringComparison]::Ordinal) -lt 0) 'Community workflow must not invoke the removed approval client.'
    Assert-Condition ($workflow -match 'actions/checkout@[0-9a-f]{40}') 'Certified workflow must pin actions/checkout to a full commit SHA.'
    Assert-Condition ($workflow -match 'actions/setup-java@[0-9a-f]{40}') 'Certified workflow must pin actions/setup-java to a full commit SHA.'
    Assert-Condition ($workflow -notmatch 'uses:\s+[^\r\n]+@(v\d+|main|master)(?:\s|$)') 'Certified workflow must not use movable Action tags or branches.'
    $nplUpload = [regex]::Match(
        $workflow,
        'gh release upload[^\r\n]+\$env:PACKAGE_FILE[^\r\n]*',
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Condition $nplUpload.Success 'Certified workflow does not upload the locally verified NPL package.'
    Assert-Condition ($nplUpload.Value -notmatch '--clobber') 'Certified workflow must never overwrite an existing NPL release asset.'
    Assert-Condition ($workflow.IndexOf('Get-FileHash -LiteralPath $remoteAsset', [System.StringComparison]::Ordinal) -ge 0) 'Certified workflow must hash an existing remote NPL before reusing it.'
    Assert-Condition ($workflow.IndexOf('Existing NPL asset differs from the local package', [System.StringComparison]::Ordinal) -ge 0) 'Certified workflow must fail closed when a same-name NPL contains different bytes.'

    Write-Host 'Publishing tool tests passed.'
} finally {
    $env:HMCLCE_PLUGIN_SIGNING_KEY = $previousSigningKey
    $env:HMCLCE_PLUGIN_CERTIFICATE = $previousCertificate
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}
