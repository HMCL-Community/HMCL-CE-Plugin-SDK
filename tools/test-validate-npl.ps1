$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-Condition([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function New-BaseManifest([int]$SchemaVersion) {
    $manifest = [ordered]@{
        schemaVersion = $SchemaVersion
        id = 'dev.hmclce.validator.fixture'
        name = 'Validator Fixture'
        version = '1.0.0'
        type = 'java'
        entrypoint = 'dev.hmclce.validator.FixturePlugin'
        permissions = @()
        requiredPermissions = @()
        launcherVersion = '*'
        dependencies = @()
    }
    if ($SchemaVersion -eq 5) {
        $manifest.runtime = 'java'
        $manifest.abi = 2
        $manifest.platforms = @()
        $manifest.hooks = @()
        $manifest.patches = @()
    }
    return [pscustomobject]$manifest
}

function Remove-ManifestProperty($Manifest, [string]$Name) {
    $Manifest.PSObject.Properties.Remove($Name)
}

function New-FixturePackage([string]$Root, [string]$Name, $Manifest) {
    $source = Join-Path $Root $Name
    [void](New-Item -ItemType Directory -Path $source)
    $manifestPath = Join-Path $source 'plugin.json'
    [System.IO.File]::WriteAllText(
        $manifestPath,
        ($Manifest | ConvertTo-Json -Depth 20),
        [System.Text.UTF8Encoding]::new($false)
    )

    $classPath = Join-Path $source 'FixturePlugin.class'
    [System.IO.File]::WriteAllBytes($classPath, [byte[]](0xCA, 0xFE, 0xBA, 0xBE))

    $package = Join-Path $Root "$Name.npl"
    $archive = [System.IO.Compression.ZipFile]::Open($package, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $manifestPath, 'plugin.json') | Out-Null
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $classPath,
            'dev/hmclce/validator/FixturePlugin.class'
        ) | Out-Null
    } finally {
        $archive.Dispose()
    }
    return $package
}

function Invoke-ValidatorProcess([string]$Package, [string]$StoreManifest = '') {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $script:PowerShellExecutable
    $startInfo.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$script:Validator`" -Package `"$Package`""
    if (-not [string]::IsNullOrWhiteSpace($StoreManifest)) {
        $startInfo.Arguments += " -StoreManifest `"$StoreManifest`""
    }
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    $process.Dispose()
    $output = $standardOutput + $standardError
    return [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
}

function Assert-ValidatorResult($Result, [string]$Name, [bool]$ShouldSucceed, [string]$ExpectedMessage) {
    if ($ShouldSucceed) {
        Assert-Condition ($Result.ExitCode -eq 0) `
            "${Name}: expected success, exit $($Result.ExitCode). Output: $($Result.Output)"
    } else {
        Assert-Condition ($Result.ExitCode -ne 0) "${Name}: expected validator failure"
        Assert-Condition ($Result.Output.Contains($ExpectedMessage)) `
            "${Name}: expected '$ExpectedMessage'. Output: $($Result.Output)"
    }
}

function Invoke-ValidatorCase(
        [string]$Temporary,
        [string]$Name,
        $Manifest,
        [bool]$ShouldSucceed,
        [string]$ExpectedMessage) {
    $package = New-FixturePackage $Temporary $Name $Manifest
    Assert-ValidatorResult (Invoke-ValidatorProcess $package) $Name $ShouldSucceed $ExpectedMessage
}

$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ('hmclce-validate-npl-test-' + [guid]::NewGuid())
[void](New-Item -ItemType Directory -Path $temporary)
$script:Validator = Join-Path $PSScriptRoot 'validate-npl.ps1'
$script:PowerShellExecutable = (Get-Process -Id $PID).Path
$passed = 0
$failures = [System.Collections.Generic.List[string]]::new()

function Test-Manifest(
        [string]$Name,
        $Manifest,
        [bool]$ShouldSucceed,
        [string]$ExpectedMessage = '') {
    try {
        Invoke-ValidatorCase $temporary $Name $Manifest $ShouldSucceed $ExpectedMessage
        $script:passed++
    } catch {
        $script:failures.Add($_.Exception.Message)
    }
}

function Test-StoreManifest(
        [string]$Name,
        $StoreVersion,
        [string]$ExpectedMessage) {
    try {
        $manifest = New-BaseManifest 5
        $package = New-FixturePackage $temporary $Name $manifest
        $completeStoreVersion = [pscustomobject][ordered]@{
            version = $manifest.version
            pluginApiVersion = 5
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $package).Hash.ToLowerInvariant()
            size = (Get-Item -LiteralPath $package).Length
            launcherVersion = '*'
            dependencies = @()
        }
        foreach ($property in $StoreVersion.PSObject.Properties) {
            $completeStoreVersion | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
        }
        $store = [pscustomobject][ordered]@{
            schemaVersion = 2
            id = $manifest.id
            versions = @($completeStoreVersion)
        }
        $storePath = Join-Path $temporary "$Name-store.json"
        [System.IO.File]::WriteAllText(
            $storePath,
            ($store | ConvertTo-Json -Depth 20),
            [System.Text.UTF8Encoding]::new($false)
        )
        Assert-ValidatorResult (Invoke-ValidatorProcess $package $storePath) $Name $false $ExpectedMessage
        $script:passed++
    } catch {
        $script:failures.Add($_.Exception.Message)
    }
}

try {
    Test-Manifest 'valid-v4' (New-BaseManifest 4) $true

    $validV5 = New-BaseManifest 5
    $validV5.platforms = @('linux', 'windows-x64')
    Test-Manifest 'valid-v5-java-abi2' $validV5 $true

    $validV5Abi1 = New-BaseManifest 5
    $validV5Abi1.abi = 1
    Test-Manifest 'valid-v5-java-abi1' $validV5Abi1 $true

    $missingRuntime = New-BaseManifest 5
    Remove-ManifestProperty $missingRuntime 'runtime'
    Test-Manifest 'missing-runtime' $missingRuntime $false 'Schema-v5 plugin manifest must declare runtime'

    $nullRuntime = New-BaseManifest 5
    $nullRuntime.runtime = $null
    Test-Manifest 'null-runtime' $nullRuntime $false 'Plugin manifest runtime cannot be null'

    $nonStringRuntime = New-BaseManifest 5
    $nonStringRuntime.runtime = 42 | ConvertTo-Json | ConvertFrom-Json
    $runtimeNumberType = $nonStringRuntime.runtime.GetType().FullName
    Test-Manifest 'nonstring-runtime' $nonStringRuntime $false `
        "Plugin manifest runtime must be a string; found $runtimeNumberType value 42"

    $blankRuntime = New-BaseManifest 5
    $blankRuntime.runtime = '   '
    Test-Manifest 'blank-runtime' $blankRuntime $false 'Plugin manifest runtime cannot be blank'

    $noncanonicalRuntime = New-BaseManifest 5
    $noncanonicalRuntime.runtime = ' Java '
    Test-Manifest 'noncanonical-runtime' $noncanonicalRuntime $false 'Plugin runtime identifier must be canonical:  Java '

    $missingAbi = New-BaseManifest 5
    Remove-ManifestProperty $missingAbi 'abi'
    Test-Manifest 'missing-abi' $missingAbi $false 'Schema-v5 plugin manifest must declare abi'

    $nullAbi = New-BaseManifest 5
    $nullAbi.abi = $null
    Test-Manifest 'null-abi' $nullAbi $false 'Plugin manifest abi cannot be null'

    $nonIntegerAbi = New-BaseManifest 5
    $nonIntegerAbi.abi = '2'
    Test-Manifest 'noninteger-abi' $nonIntegerAbi $false 'Plugin manifest abi must be an integer: 2'

    foreach ($unsupportedAbi in @(0, 3)) {
        $manifest = New-BaseManifest 5
        $manifest.abi = $unsupportedAbi
        Test-Manifest "unsupported-abi-$unsupportedAbi" $manifest $false "Unsupported plugin manifest abi: $unsupportedAbi"
    }

    $invalidPlatformsType = New-BaseManifest 5
    $invalidPlatformsType.platforms = 'windows-x64'
    Test-Manifest 'invalid-platforms-type' $invalidPlatformsType $false 'Plugin platforms must be an array'

    $invalidPlatform = New-BaseManifest 5
    $invalidPlatform.platforms = @('windows-sparc')
    Test-Manifest 'invalid-platform' $invalidPlatform $false 'Invalid plugin platform target: windows-sparc'

    $noncanonicalPlatform = New-BaseManifest 5
    $noncanonicalPlatform.platforms = @('Windows-X64')
    Test-Manifest 'noncanonical-platform' $noncanonicalPlatform $false 'Plugin platform target must be canonical: Windows-X64'

    $duplicatePlatforms = New-BaseManifest 5
    $duplicatePlatforms.platforms = @('windows-x64', 'windows-x64')
    Test-Manifest 'duplicate-platforms' $duplicatePlatforms $false 'Duplicate plugin platform target: windows-x64'

    $missingPlatforms = New-BaseManifest 5
    Remove-ManifestProperty $missingPlatforms 'platforms'
    Test-Manifest 'missing-platforms' $missingPlatforms $true

    $nullPlatforms = New-BaseManifest 5
    $nullPlatforms.platforms = $null
    Test-Manifest 'null-platforms' $nullPlatforms $false 'Plugin platforms cannot be null'

    $allHooks = New-BaseManifest 5
    $allHooks.permissions = @('launcher-hook')
    $allHooks.requiredPermissions = @('launcher-hook')
    $allHooks.hooks = @(
        'before-download', 'after-download',
        'before-game-launch', 'after-game-launch',
        'before-login', 'after-login',
        'before-instance-create', 'after-instance-create',
        'before-mod-install', 'after-mod-install',
        'before-settings-load', 'after-settings-load'
    )
    Test-Manifest 'all-hooks-with-both-permissions' $allHooks $true

    $nullHooks = New-BaseManifest 5
    $nullHooks.hooks = $null
    Test-Manifest 'null-hooks' $nullHooks $false 'Plugin hooks cannot be null'

    $nonArrayHooks = New-BaseManifest 5
    $nonArrayHooks.hooks = 'before-download'
    Test-Manifest 'nonarray-hooks' $nonArrayHooks $false 'Plugin hooks must be an array'

    $unknownHook = New-BaseManifest 5
    $unknownHook.hooks = @('around-launch')
    Test-Manifest 'unknown-hook' $unknownHook $false 'Unknown plugin hook point: around-launch'

    $duplicateHooks = New-BaseManifest 5
    $duplicateHooks.hooks = @('before-download', 'before-download')
    Test-Manifest 'duplicate-hooks' $duplicateHooks $false 'Duplicate plugin hook point: before-download'

    $invalidPatchTarget = New-BaseManifest 5
    $invalidPatchTarget.patches = @([pscustomobject]@{
        target = 'GameLaunchService'; method = 'launch'; type = 'before'; parameters = @()
    })
    Test-Manifest 'invalid-patch-target' $invalidPatchTarget $false 'Invalid patch target class: GameLaunchService'

    $invalidPatchMethod = New-BaseManifest 5
    $invalidPatchMethod.patches = @([pscustomobject]@{
        target = 'org.example.GameLaunchService'; method = 'bad-method'; type = 'before'; parameters = @()
    })
    Test-Manifest 'invalid-patch-method' $invalidPatchMethod $false 'Invalid patch method name: bad-method'

    $invalidPatchType = New-BaseManifest 5
    $invalidPatchType.patches = @([pscustomobject]@{
        target = 'org.example.GameLaunchService'; method = 'launch'; type = 'around'; parameters = @()
    })
    Test-Manifest 'invalid-patch-type' $invalidPatchType $false 'Unknown plugin patch type: around'

    $missingPatchParameters = New-BaseManifest 5
    $patchWithoutParameters = [pscustomobject]@{
        target = 'org.example.GameLaunchService'; method = 'launch'; type = 'before'
    }
    $missingPatchParameters.patches = @($patchWithoutParameters)
    Test-Manifest 'missing-patch-parameters' $missingPatchParameters $false `
        'Missing patch parameters for org.example.GameLaunchService.launch'

    $invalidPatchParametersType = New-BaseManifest 5
    $invalidPatchParametersType.patches = @([pscustomobject]@{
        target = 'org.example.GameLaunchService'; method = 'launch'; type = 'before'; parameters = 'java.lang.String'
    })
    Test-Manifest 'invalid-patch-parameters-type' $invalidPatchParametersType $false `
        'Patch parameters must be an array for org.example.GameLaunchService.launch'

    $invalidPatchParameter = New-BaseManifest 5
    $invalidPatchParameter.patches = @([pscustomobject]@{
        target = 'org.example.GameLaunchService'; method = 'launch'; type = 'before'; parameters = @(' ')
    })
    Test-Manifest 'invalid-patch-parameter' $invalidPatchParameter $false `
        'Patch parameter cannot be null or blank for org.example.GameLaunchService.launch'

    $duplicatePatches = New-BaseManifest 5
    $duplicatePatches.patches = @(
        [pscustomobject]@{ target = 'org.example.GameLaunchService'; method = 'launch'; type = 'before'; parameters = @('java.lang.String') },
        [pscustomobject]@{ target = 'org.example.GameLaunchService'; method = 'launch'; type = 'before'; parameters = @('java.lang.String') }
    )
    Test-Manifest 'duplicate-patches' $duplicatePatches $false `
        'Duplicate plugin patch declaration: org.example.GameLaunchService.launch'

    $nullPatches = New-BaseManifest 5
    $nullPatches.patches = $null
    Test-Manifest 'null-patches' $nullPatches $false 'Plugin patches cannot be null'

    $nonArrayPatches = New-BaseManifest 5
    $nonArrayPatches.patches = [pscustomobject]@{
        target = 'org.example.GameLaunchService'; method = 'launch'; type = 'before'; parameters = @()
    }
    Test-Manifest 'nonarray-patches' $nonArrayPatches $false 'Plugin patches must be an array'

    $orderedPatchParameters = New-BaseManifest 5
    $orderedPatchParameters.permissions = @('launcher-patch')
    $orderedPatchParameters.requiredPermissions = @('launcher-patch')
    $orderedPatchParameters.patches = @(
        [pscustomobject]@{ target = 'org.example.GameLaunchService'; method = 'launch'; type = 'before'; parameters = @('java.lang.String', 'int') },
        [pscustomobject]@{ target = 'org.example.GameLaunchService'; method = 'launch'; type = 'before'; parameters = @('int', 'java.lang.String') }
    )
    Test-Manifest 'ordered-patch-parameters' $orderedPatchParameters $true

    $hookMissingPermission = New-BaseManifest 5
    $hookMissingPermission.hooks = @('before-download')
    Test-Manifest 'hook-missing-permission' $hookMissingPermission $false `
        'Plugin hooks require launcher-hook in permissions and requiredPermissions'

    $hookMissingRequiredPermission = New-BaseManifest 5
    $hookMissingRequiredPermission.permissions = @('launcher-hook')
    $hookMissingRequiredPermission.hooks = @('before-download')
    Test-Manifest 'hook-missing-required-permission' $hookMissingRequiredPermission $false `
        'Plugin hooks require launcher-hook in permissions and requiredPermissions'

    $patchMissingPermission = New-BaseManifest 5
    $patchMissingPermission.patches = @([pscustomobject]@{
        target = 'org.example.GameLaunchService'; method = 'launch'; type = 'after'; parameters = @()
    })
    Test-Manifest 'patch-missing-permission' $patchMissingPermission $false `
        'Plugin patches require launcher-patch in permissions and requiredPermissions'

    $patchMissingRequiredPermission = New-BaseManifest 5
    $patchMissingRequiredPermission.permissions = @('launcher-patch')
    $patchMissingRequiredPermission.patches = @([pscustomobject]@{
        target = 'org.example.GameLaunchService'; method = 'launch'; type = 'replace'; parameters = @()
    })
    Test-Manifest 'patch-missing-required-permission' $patchMissingRequiredPermission $false `
        'Plugin patches require launcher-patch in permissions and requiredPermissions'

    $missingLauncherVersion = New-BaseManifest 5
    Remove-ManifestProperty $missingLauncherVersion 'launcherVersion'
    Test-Manifest 'v5-missing-launcher-version' $missingLauncherVersion $false `
        'schemaVersion 5 requires launcherVersion'

    $v5MinimumLauncherVersion = New-BaseManifest 5
    $v5MinimumLauncherVersion | Add-Member -NotePropertyName 'minLauncherVersion' -NotePropertyValue '27.0'
    Test-Manifest 'v5-min-launcher-version' $v5MinimumLauncherVersion $false `
        'schemaVersion 5 uses launcherVersion and cannot declare minLauncherVersion'

    Test-StoreManifest 'store-v5-missing-permissions' ([pscustomobject][ordered]@{
        requiredPermissions = @()
    }) 'Store pluginApiVersion 5 must declare permissions as an array'
    Test-StoreManifest 'store-v5-missing-required-permissions' ([pscustomobject][ordered]@{
        permissions = @()
    }) 'Store pluginApiVersion 5 must declare requiredPermissions as an array'

    foreach ($field in @('runtime', 'abi', 'platforms', 'hooks', 'patches')) {
        $manifest = New-BaseManifest 4
        if ($field -eq 'runtime') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue 'java' }
        if ($field -eq 'abi') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue 1 }
        if ($field -eq 'platforms') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue @() }
        if ($field -eq 'hooks') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue @() }
        if ($field -eq 'patches') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue @() }
        Test-Manifest "v5-$field-under-v4" $manifest $false `
            'Plugin manifest schemaVersion 4 cannot declare schema-v5 runtime capabilities'
    }

    foreach ($permission in @('launcher-hook', 'launcher-patch')) {
        $manifest = New-BaseManifest 4
        $manifest.permissions = @($permission)
        $manifest.requiredPermissions = @($permission)
        Test-Manifest "$permission-under-v4" $manifest $false `
            'Plugin manifest schemaVersion 4 cannot declare schema-v5 launcher permissions'
    }

    if ($failures.Count -gt 0) {
        throw "$($failures.Count) of $($passed + $failures.Count) validator tests failed:`n$($failures -join "`n")"
    }
    Write-Host "$passed validator tests passed."
} finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}
