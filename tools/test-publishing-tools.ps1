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


    $workflow = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\store\github-release-workflow.yml') -Raw -Encoding utf8
    $signInvocation = $workflow.IndexOf('./tools/sign-plugin.ps1', [System.StringComparison]::Ordinal)
    $storeValidationInvocation = $workflow.IndexOf(
        './tools/validate-npl.ps1 -Package $package.FullName -StoreManifest ./manifest.json',
        [System.StringComparison]::Ordinal
    )
    $draftReleaseStep = $workflow.IndexOf('- name: Create or update draft release', [System.StringComparison]::Ordinal)
    $manifestPublishStep = $workflow.IndexOf('- name: Publish manifest on the default branch', [System.StringComparison]::Ordinal)
    $releasePublishStep = $workflow.IndexOf('- name: Publish release', [System.StringComparison]::Ordinal)
    Assert-Condition ($signInvocation -ge 0) 'Community workflow must generate manifest.json with sign-plugin.ps1.'
    Assert-Condition ($storeValidationInvocation -gt $signInvocation) 'Community workflow must reconcile the exact NPL with generated manifest.json after signing.'
    Assert-Condition ($draftReleaseStep -gt $storeValidationInvocation) 'Community workflow must reconcile Store metadata before creating or publishing a Release.'
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

    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $attributes = Get-Content -LiteralPath (Join-Path $repositoryRoot '.gitattributes') -Raw -Encoding utf8
    Assert-Condition ($attributes -match '(?m)^examples/\*\*/plugin\.json text eol=lf\r?$') 'Repository attributes must enforce LF for example plugin manifests.'

    foreach ($example in @('java-helloworld', 'kotlin-helloworld', 'java-mixin', 'offline-unlocker')) {
        $buildFile = Join-Path $repositoryRoot "examples\$example\build.gradle.kts"
        $buildScript = Get-Content -LiteralPath $buildFile -Raw -Encoding utf8
        Assert-Condition ($buildScript.IndexOf('tasks.withType<AbstractArchiveTask>().configureEach {', [System.StringComparison]::Ordinal) -ge 0) "$example must configure every archive task for reproducibility."
        Assert-Condition ($buildScript.IndexOf('isPreserveFileTimestamps = false', [System.StringComparison]::Ordinal) -ge 0) "$example must disable archive file timestamps."
        Assert-Condition ($buildScript.IndexOf('isReproducibleFileOrder = true', [System.StringComparison]::Ordinal) -ge 0) "$example must use reproducible archive file order."
        Assert-Condition ($buildScript.IndexOf('../../../../HMCL-CE/HMCL/build/libs', [System.StringComparison]::Ordinal) -ge 0) "$example must resolve the sibling HMCL repository from its project directory."
    }

    foreach ($guide in @('README.md', 'docs\PLUGIN_QUICKSTART.md')) {
        $guideText = Get-Content -LiteralPath (Join-Path $repositoryRoot $guide) -Raw -Encoding utf8
        Assert-Condition ($guideText.IndexOf('../../HMCL-CE/HMCL/build/libs', [System.StringComparison]::Ordinal) -ge 0) "$guide must resolve HMCL build output from the SDK root."
        Assert-Condition ($guideText.IndexOf('../../HMCL-CE/gradlew.bat', [System.StringComparison]::Ordinal) -ge 0) "$guide must invoke the HMCL wrapper from the SDK root."
    }

    $offlineGuide = Get-Content -LiteralPath (Join-Path $repositoryRoot 'examples\offline-unlocker\README.md') -Raw -Encoding utf8
    Assert-Condition ($offlineGuide.IndexOf('schemaVersion: 5', [System.StringComparison]::Ordinal) -ge 0) 'Offline Unlocker guide must document schema v5.'
    Assert-Condition ($offlineGuide.IndexOf('runtime: java', [System.StringComparison]::Ordinal) -ge 0) 'Offline Unlocker guide must document the Java runtime provider.'
    Assert-Condition ($offlineGuide.IndexOf('ABI: 2', [System.StringComparison]::Ordinal) -ge 0) 'Offline Unlocker guide must document ABI 2.'
    Assert-Condition ($offlineGuide.IndexOf('language-neutral', [System.StringComparison]::Ordinal) -ge 0) 'Offline Unlocker guide must preserve the multilingual schema-v5 boundary.'
    Assert-Condition ($offlineGuide.IndexOf('SDK v4', [System.StringComparison]::Ordinal) -lt 0) 'Offline Unlocker guide must not claim SDK v4 compliance.'
    Assert-Condition ($offlineGuide.IndexOf('..\..\HMCL-CE\gradlew.bat', [System.StringComparison]::Ordinal) -ge 0) 'Offline Unlocker guide must invoke the HMCL wrapper from the SDK root.'
    Assert-Condition ($offlineGuide.IndexOf('..\..\..\..\HMCL-CE\HMCL\build\libs', [System.StringComparison]::Ordinal) -ge 0) 'Offline Unlocker regression guide must resolve HMCL from the example directory.'
    Assert-Condition ($offlineGuide -notmatch '(?m)^- [^:\r\n]+: \d+ [^\r\n]+$') 'Offline Unlocker guide must not hard-code generated package size.'
    Assert-Condition ($offlineGuide -notmatch '(?m)^- SHA-256: [0-9a-f]{64}$') 'Offline Unlocker guide must not hard-code generated package hash.'

    $storeGuide = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docs\PLUGIN_STORE_SETUP.md') -Raw -Encoding utf8
    Assert-Condition ($storeGuide.IndexOf('gradle wrapper --gradle-version 9.6.1', [System.StringComparison]::Ordinal) -ge 0) 'Store guide must provide the Gradle Wrapper generation command.'
    foreach ($wrapperFile in @('gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar', 'gradle/wrapper/gradle-wrapper.properties')) {
        Assert-Condition ($storeGuide.IndexOf($wrapperFile, [System.StringComparison]::Ordinal) -ge 0) "Store guide must require committing $wrapperFile."
    }
    $wrapperAdd = $storeGuide.IndexOf('git add gradlew gradlew.bat gradle/wrapper/gradle-wrapper.jar gradle/wrapper/gradle-wrapper.properties', [System.StringComparison]::Ordinal)
    $wrapperMode = $storeGuide.IndexOf('git update-index --chmod=+x gradlew', [System.StringComparison]::Ordinal)
    $wrapperCommit = $storeGuide.IndexOf('git commit -m "Add Gradle Wrapper for plugin releases"', [System.StringComparison]::Ordinal)
    Assert-Condition ($wrapperAdd -ge 0) 'Store guide must stage every Gradle Wrapper file before updating its executable mode.'
    Assert-Condition ($wrapperMode -gt $wrapperAdd) 'Store guide must stage gradlew before updating its executable mode.'
    Assert-Condition ($wrapperCommit -gt $wrapperMode) 'Store guide must update the gradlew executable mode before committing the Gradle Wrapper.'

    Write-Host 'Publishing tool tests passed.'
} finally {
    $env:HMCLCE_PLUGIN_SIGNING_KEY = $previousSigningKey
    $env:HMCLCE_PLUGIN_CERTIFICATE = $previousCertificate
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}
