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

function New-RuntimeDeclaration(
        [string]$Runtime = 'rust',
        $Abis = @(1, 2),
        $BridgeAbi = 1,
        $ExecutionModes = @('embedded', 'isolated'),
        $Features = @('bridge')) {
    return [pscustomobject][ordered]@{
        runtime = $Runtime
        abis = $Abis
        bridgeAbi = $BridgeAbi
        executionModes = $ExecutionModes
        features = $Features
    }
}

function New-StoreArtifact(
        [string]$Platform = 'windows-x64',
        $Size = 1,
        [string]$Sha256 = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa') {
    return [pscustomobject][ordered]@{
        platform = $Platform
        packageUrl = "https://example.test/plugin-$Platform.npl"
        sha256 = $Sha256
        size = $Size
    }
}

function Remove-ManifestProperty($Manifest, [string]$Name) {
    $Manifest.PSObject.Properties.Remove($Name)
}

function Add-ManifestArrayProperty($Manifest, [string]$Name, [object[]]$Values) {
    $Manifest | Add-Member -NotePropertyName $Name -NotePropertyValue $null
    $Manifest.PSObject.Properties[$Name].Value = $Values
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

    $runtimePayloadPath = $null
    $runtimePayloadEntry = $null
    if ($Manifest.schemaVersion -eq 5 -and
            $Manifest.runtime -is [string] -and
            [string]$Manifest.runtime -cne 'java' -and
            $Manifest.entrypoint -is [string]) {
        $candidate = [string]$Manifest.entrypoint
        if ($candidate -match '^[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*$' -and
                $candidate.Split('/') -notcontains '..') {
            $runtimePayloadEntry = $candidate
            $runtimePayloadPath = Join-Path $source ($candidate.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
            [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $runtimePayloadPath))
            [System.IO.File]::WriteAllBytes($runtimePayloadPath, [byte[]](0x48, 0x4D, 0x43, 0x4C))
        } elseif ($candidate -cne $candidate.Trim() -and
                $candidate.Trim() -match '^[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*$') {
            $runtimePayloadEntry = $candidate
            $runtimePayloadPath = Join-Path $source 'whitespace-runtime-payload.bin'
            [System.IO.File]::WriteAllBytes($runtimePayloadPath, [byte[]](0x48, 0x4D, 0x43, 0x4C))
        }
    }

    $extensionManifestPath = $null
    $entryAssemblyPath = $null
    if ([string]$Manifest.type -ceq 'csharp') {
        $extensionManifestPath = Join-Path $source 'extension.json'
        $extensionManifest = [ordered]@{
            id = $Manifest.id
            version = $Manifest.version
            entryAssembly = 'FixturePlugin.dll'
        }
        [System.IO.File]::WriteAllText(
            $extensionManifestPath,
            ($extensionManifest | ConvertTo-Json -Depth 5),
            [System.Text.UTF8Encoding]::new($false)
        )
        $entryAssemblyPath = Join-Path $source 'FixturePlugin.dll'
        [System.IO.File]::WriteAllBytes($entryAssemblyPath, [byte[]](0x4D, 0x5A))
    }

    $package = Join-Path $Root "$Name.npl"
    $archive = [System.IO.Compression.ZipFile]::Open($package, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $manifestPath, 'plugin.json') | Out-Null
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $classPath,
            'dev/hmclce/validator/FixturePlugin.class'
        ) | Out-Null
        if ($null -ne $runtimePayloadPath) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive,
                $runtimePayloadPath,
                $runtimePayloadEntry
            ) | Out-Null
        }
        if ($null -ne $extensionManifestPath) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive,
                $extensionManifestPath,
                'companion/extension.json'
            ) | Out-Null
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive,
                $entryAssemblyPath,
                'companion/FixturePlugin.dll'
            ) | Out-Null
        }
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
    $started = $false
    try {
        [void]$process.Start()
        $started = $true
        $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) {
            throw "Validator process timed out for package: $Package"
        }
        $readTasks = [System.Threading.Tasks.Task[]]@($standardOutputTask, $standardErrorTask)
        if (-not [System.Threading.Tasks.Task]::WaitAll($readTasks, 5000)) {
            throw "Validator output streams timed out for package: $Package"
        }
        $process.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Output = $standardOutputTask.Result + $standardErrorTask.Result
        }
    } finally {
        if ($started -and -not $process.HasExited) {
            try {
                $process.Kill()
                [void]$process.WaitForExit(5000)
            } catch {
                # The process may exit between the HasExited check and Kill.
            }
        }
        $process.Dispose()
    }
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
        $Manifest,
        $StoreVersionOverrides,
        [bool]$ShouldSucceed,
        [string]$ExpectedMessage = '',
        [string[]]$RemoveFields = @(),
        $StoreSchemaVersion = 2,
        [bool]$UseArtifactMatrix = $false,
        [string]$RawArtifactSize = '') {
    try {
        $package = New-FixturePackage $temporary $Name $Manifest
        $completeStoreVersion = [pscustomobject][ordered]@{
            version = $Manifest.version
            pluginApiVersion = $Manifest.schemaVersion
            packageUrl = "https://example.test/$Name.npl"
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $package).Hash.ToLowerInvariant()
            size = (Get-Item -LiteralPath $package).Length
            permissions = @($Manifest.permissions)
            requiredPermissions = @($Manifest.requiredPermissions)
            launcherVersion = $Manifest.launcherVersion
            dependencies = @($Manifest.dependencies)
        }
        if ([int64]$Manifest.schemaVersion -eq 5) {
            $completeStoreVersion | Add-Member -NotePropertyName 'runtime' -NotePropertyValue $Manifest.runtime
            $completeStoreVersion | Add-Member -NotePropertyName 'abi' -NotePropertyValue $Manifest.abi
            $completeStoreVersion | Add-Member -NotePropertyName 'platforms' -NotePropertyValue @($Manifest.platforms)
            foreach ($field in @('pluginKind', 'executionMode', 'runtimeProvider', 'providesRuntimes')) {
                $property = $Manifest.PSObject.Properties[$field]
                if ($null -ne $property) {
                    $completeStoreVersion | Add-Member -NotePropertyName $field -NotePropertyValue $property.Value
                }
            }
        }
        if ($UseArtifactMatrix) {
            $artifactPlatform = if (@($Manifest.platforms).Count -gt 0) {
                @($Manifest.platforms)[0]
            } else {
                'windows-x64'
            }
            $completeStoreVersion | Add-Member -NotePropertyName 'artifacts' -NotePropertyValue @(
                [pscustomobject][ordered]@{
                    platform = $artifactPlatform
                    packageUrl = "https://example.test/$Name-$artifactPlatform.npl"
                    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $package).Hash.ToLowerInvariant()
                    size = (Get-Item -LiteralPath $package).Length
                }
            )
            foreach ($field in @('packageUrl', 'sha256', 'size')) {
                Remove-ManifestProperty $completeStoreVersion $field
            }
        }
        foreach ($field in $RemoveFields) {
            Remove-ManifestProperty $completeStoreVersion $field
        }
        foreach ($property in $StoreVersionOverrides.PSObject.Properties) {
            $existing = $completeStoreVersion.PSObject.Properties[$property.Name]
            if ($null -eq $existing) {
                $completeStoreVersion | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
            } else {
                $existing.Value = $property.Value
            }
        }
        $store = [pscustomobject][ordered]@{
            schemaVersion = $StoreSchemaVersion
            id = $Manifest.id
            versions = @($completeStoreVersion)
        }
        $rawSizeMarker = '__HMCLCE_RAW_ARTIFACT_SIZE__'
        if (-not [string]::IsNullOrWhiteSpace($RawArtifactSize)) {
            Assert-Condition ($UseArtifactMatrix -and @($completeStoreVersion.artifacts).Count -eq 1) `
                'Raw artifact-size fixtures require exactly one Store artifact.'
            $completeStoreVersion.artifacts[0].size = $rawSizeMarker
        }
        $storePath = Join-Path $temporary "$Name-store.json"
        $storeJson = $store | ConvertTo-Json -Depth 20
        if (-not [string]::IsNullOrWhiteSpace($RawArtifactSize)) {
            $quotedMarker = '"' + $rawSizeMarker + '"'
            Assert-Condition ([regex]::Matches($storeJson, [regex]::Escape($quotedMarker)).Count -eq 1) `
                'Raw artifact-size fixture marker was not serialized exactly once.'
            $storeJson = $storeJson.Replace($quotedMarker, $RawArtifactSize)
            $rawSizePattern = '"size"\s*:\s*' + [regex]::Escape($RawArtifactSize) + '\s*(?:,|\r?\n\s*})'
            Assert-Condition ($storeJson -match $rawSizePattern) `
                "Raw artifact-size fixture did not preserve JSON token: $RawArtifactSize"
        }
        [System.IO.File]::WriteAllText(
            $storePath,
            $storeJson,
            [System.Text.UTF8Encoding]::new($false)
        )
        Assert-ValidatorResult (Invoke-ValidatorProcess $package $storePath) `
            $Name $ShouldSucceed $ExpectedMessage
        $script:passed++
    } catch {
        $script:failures.Add($_.Exception.Message)
    }
}

try {
    Test-Manifest 'valid-v4' (New-BaseManifest 4) $true

    $overflowSchemaVersion = New-BaseManifest 4
    $overflowSchemaVersion.schemaVersion = [int64]2147483648
    Test-Manifest 'overflow-schema-version' $overflowSchemaVersion $false `
        'Plugin schemaVersion is outside Int32 range: 2147483648'

    $validV5 = New-BaseManifest 5
    $validV5.platforms = @('linux', 'windows-x64')
    Test-Manifest 'valid-v5-java-abi2' $validV5 $true

    $validV5Abi1 = New-BaseManifest 5
    $validV5Abi1.abi = 1
    Test-Manifest 'valid-v5-java-abi1' $validV5Abi1 $true

    $validProvider = New-BaseManifest 5
    $validProvider.platforms = @('windows-x64')
    $validProvider | Add-Member -NotePropertyName 'pluginKind' -NotePropertyValue 'runtime-provider'
    Add-ManifestArrayProperty $validProvider 'providesRuntimes' @(
        (New-RuntimeDeclaration 'rust' @(1, 2) 1 @('isolated') @('bridge', 'hooks'))
    )
    Test-StoreManifest 'valid-v5-java-runtime-provider' $validProvider `
        ([pscustomobject][ordered]@{}) $true '' @() 2 $true

    $validRust = New-BaseManifest 5
    $validRust.runtime = 'rust'
    $validRust.entrypoint = 'payload/plugin.rust'
    $validRust.platforms = @('windows-x64')
    $validRust | Add-Member -NotePropertyName 'executionMode' -NotePropertyValue 'isolated'
    $validRust | Add-Member -NotePropertyName 'runtimeProvider' `
        -NotePropertyValue 'dev.hmclce.runtime.rust-host'
    Test-Manifest 'valid-v5-rust-language-plugin' $validRust $true

    $whitespaceRuntimeEntrypoint = New-BaseManifest 5
    $whitespaceRuntimeEntrypoint.runtime = 'rust'
    $whitespaceRuntimeEntrypoint.entrypoint = ' payload/plugin.rust '
    Test-Manifest 'runtime-entrypoint-outer-whitespace' $whitespaceRuntimeEntrypoint $false `
        'Invalid runtime payload entrypoint:  payload/plugin.rust '

    foreach ($mode in @('embedded', 'isolated')) {
        $manifest = New-BaseManifest 5
        $manifest | Add-Member -NotePropertyName 'executionMode' -NotePropertyValue $mode
        Test-Manifest "valid-execution-mode-$mode" $manifest $true
    }

    $futureProviderAbi = New-BaseManifest 5
    $futureProviderAbi | Add-Member -NotePropertyName 'pluginKind' -NotePropertyValue 'runtime-provider'
    Add-ManifestArrayProperty $futureProviderAbi 'providesRuntimes' @(
        (New-RuntimeDeclaration 'rust' @(2, 3) 2 @('embedded') @('bridge'))
    )
    Test-Manifest 'valid-future-provider-abis' $futureProviderAbi $true

    $invalidProviderCases = @(
        @('provider-nonjava-bootstrap', 'Runtime-provider plugins must use the java runtime', {
            $m = New-BaseManifest 5; $m.runtime = 'rust'; $m.entrypoint = 'payload/provider.bin'
            $m | Add-Member -NotePropertyName pluginKind -NotePropertyValue 'runtime-provider'; Add-ManifestArrayProperty $m 'providesRuntimes' @((New-RuntimeDeclaration)); $m
        }),
        @('provider-pins-provider', 'Runtime-provider plugins cannot pin another runtime provider', {
            $m = New-BaseManifest 5; $m | Add-Member -NotePropertyName pluginKind -NotePropertyValue 'runtime-provider'
            $m | Add-Member -NotePropertyName runtimeProvider -NotePropertyValue 'dev.hmclce.runtime.other'; Add-ManifestArrayProperty $m 'providesRuntimes' @((New-RuntimeDeclaration)); $m
        }),
        @('provider-isolated-bootstrap', 'Runtime-provider plugins must use embedded Java bootstrap execution', {
            $m = New-BaseManifest 5; $m | Add-Member -NotePropertyName pluginKind -NotePropertyValue 'runtime-provider'; $m | Add-Member -NotePropertyName executionMode -NotePropertyValue 'isolated'
            Add-ManifestArrayProperty $m 'providesRuntimes' @((New-RuntimeDeclaration)); $m
        }),
        @('provider-empty-runtimes', 'Runtime-provider plugins must provide at least one runtime', {
            $m = New-BaseManifest 5; $m | Add-Member -NotePropertyName pluginKind -NotePropertyValue 'runtime-provider'; Add-ManifestArrayProperty $m 'providesRuntimes' @(); $m
        }),
        @('normal-provides-runtime', 'Normal plugins cannot provide runtimes', {
            $m = New-BaseManifest 5; Add-ManifestArrayProperty $m 'providesRuntimes' @((New-RuntimeDeclaration)); $m
        }),
        @('provider-built-in-java', 'Runtime-provider plugins cannot provide the built-in java runtime', {
            $m = New-BaseManifest 5; $m | Add-Member -NotePropertyName pluginKind -NotePropertyValue 'runtime-provider'
            Add-ManifestArrayProperty $m 'providesRuntimes' @((New-RuntimeDeclaration 'java')); $m
        }),
        @('provider-duplicate-runtime', 'Duplicate provided runtime: rust', {
            $m = New-BaseManifest 5; $m | Add-Member -NotePropertyName pluginKind -NotePropertyValue 'runtime-provider'
            Add-ManifestArrayProperty $m 'providesRuntimes' @((New-RuntimeDeclaration), (New-RuntimeDeclaration)); $m
        }),
        @('provider-native-without-permission', 'Native runtime providers must declare permission native-code', {
            $m = New-BaseManifest 5; $m | Add-Member -NotePropertyName pluginKind -NotePropertyValue 'runtime-provider'
            Add-ManifestArrayProperty $m 'providesRuntimes' @((New-RuntimeDeclaration 'rust' @(2) 1 @('embedded') @('bridge', 'native'))); $m
        })
    )
    foreach ($case in $invalidProviderCases) {
        Test-Manifest $case[0] (& $case[2]) $false $case[1]
    }

    $invalidProviderFieldCases = @(
        @('nonstring-plugin-kind', 'Plugin pluginKind must be a string', 'pluginKind', $true),
        @('noncanonical-plugin-kind', 'Plugin pluginKind must be canonical: RUNTIME-PROVIDER', 'pluginKind', 'RUNTIME-PROVIDER'),
        @('nonstring-execution-mode', 'Plugin executionMode must be a string', 'executionMode', 1),
        @('noncanonical-execution-mode', 'Plugin executionMode must be canonical: ISOLATED', 'executionMode', 'ISOLATED'),
        @('nonstring-runtime-provider', 'Plugin runtimeProvider must be a string or null', 'runtimeProvider', $true),
        @('numeric-runtime-provider', 'Plugin runtimeProvider must be a string or null', 'runtimeProvider', 123),
        @('noncanonical-runtime-provider', 'Invalid runtime provider plugin ID', 'runtimeProvider', ' Bad Provider '),
        @('nonarray-provides-runtimes', 'Plugin providesRuntimes must be an array', 'providesRuntimes', $true)
    )
    foreach ($case in $invalidProviderFieldCases) {
        $manifest = New-BaseManifest 5
        $manifest | Add-Member -NotePropertyName $case[2] -NotePropertyValue $case[3]
        Test-Manifest $case[0] $manifest $false $case[1]
    }

    $invalidDeclarationCases = @(
        @('null-provider-declaration', 'Plugin provided runtime declaration cannot be null', $null),
        @('nonobject-provider-declaration', 'Runtime provider declaration must be an object', 'rust'),
        @('noncanonical-provided-runtime', 'Runtime provider identifier must be canonical', (New-RuntimeDeclaration 'Rust')),
        @('empty-provider-abis', 'Runtime provider ABI set cannot be empty', (New-RuntimeDeclaration 'rust' @())),
        @('duplicate-provider-abis', 'Duplicate runtime provider ABI: 2', (New-RuntimeDeclaration 'rust' @(2, 2))),
        @('nonpositive-provider-abi', 'Runtime provider ABI must be positive', (New-RuntimeDeclaration 'rust' @(0))),
        @('fractional-provider-abi', 'Runtime provider abis must be an integer', (New-RuntimeDeclaration 'rust' @(2.5))),
        @('nonpositive-bridge-abi', 'Runtime provider bridge ABI must be positive', (New-RuntimeDeclaration 'rust' @(2) 0)),
        @('fractional-bridge-abi', 'Runtime provider bridgeAbi must be an integer', (New-RuntimeDeclaration 'rust' @(2) 1.5)),
        @('empty-provider-modes', 'runtime provider executionModes set cannot be empty', (New-RuntimeDeclaration 'rust' @(2) 1 @())),
        @('duplicate-provider-modes', 'Duplicate runtime provider executionModes value: embedded', (New-RuntimeDeclaration 'rust' @(2) 1 @('embedded', 'embedded'))),
        @('unknown-provider-mode', 'Unknown runtime provider executionModes value: direct', (New-RuntimeDeclaration 'rust' @(2) 1 @('direct'))),
        @('noncanonical-provider-mode-isolated', 'runtime provider executionModes value must be canonical: ISOLATED', (New-RuntimeDeclaration 'rust' @(2) 1 @('ISOLATED'))),
        @('empty-provider-features', 'Runtime providers must implement bridge', (New-RuntimeDeclaration 'rust' @(2) 1 @('embedded') @())),
        @('duplicate-provider-features', 'Duplicate runtime provider features value: bridge', (New-RuntimeDeclaration 'rust' @(2) 1 @('embedded') @('bridge', 'bridge'))),
        @('unknown-provider-feature', 'Unknown runtime provider features value: magic', (New-RuntimeDeclaration 'rust' @(2) 1 @('embedded') @('bridge', 'magic'))),
        @('noncanonical-provider-feature', 'runtime provider features value must be canonical: Bridge', (New-RuntimeDeclaration 'rust' @(2) 1 @('embedded') @('Bridge'))),
        @('noncanonical-provider-feature-raw-jvm', 'runtime provider features value must be canonical: RAW-JVM', (New-RuntimeDeclaration 'rust' @(2) 1 @('embedded') @('RAW-JVM')))
    )
    foreach ($case in $invalidDeclarationCases) {
        $manifest = New-BaseManifest 5
        $manifest | Add-Member -NotePropertyName 'pluginKind' -NotePropertyValue 'runtime-provider'
        $declarations = New-Object object[] 1
        $declarations[0] = $case[2]
        Add-ManifestArrayProperty $manifest 'providesRuntimes' $declarations
        Test-Manifest $case[0] $manifest $false $case[1]
    }

    $isolatedRawJvm = New-BaseManifest 5
    $isolatedRawJvm.permissions = @('jvm-raw')
    $isolatedRawJvm.requiredPermissions = @('jvm-raw')
    $isolatedRawJvm | Add-Member -NotePropertyName 'executionMode' -NotePropertyValue 'isolated'
    Test-Manifest 'isolated-raw-jvm' $isolatedRawJvm $false `
        'Isolated runtime requirements cannot require raw-jvm'

    foreach ($schemaVersion in @(4, 5)) {
        $legacyCompanion = New-BaseManifest $schemaVersion
        $legacyCompanion.type = 'csharp'
        $legacyCompanion.entrypoint = 'companion/extension.json'
        Test-Manifest "reject-schema-$schemaVersion-legacy-csharp-companion" $legacyCompanion $false `
            'Unsupported plugin type: csharp. HMCL CE accepts Java and Kotlin packages.'
    }

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

    $overflowAbi = New-BaseManifest 5
    $overflowAbi.abi = [int64]2147483648
    Test-Manifest 'overflow-abi' $overflowAbi $false `
        'Plugin manifest abi is outside Int32 range: 2147483648'

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

    $emptyOverrides = [pscustomobject][ordered]@{}
    Test-StoreManifest 'valid-store-v4' (New-BaseManifest 4) $emptyOverrides $true
    Test-StoreManifest 'valid-store-v5' (New-BaseManifest 5) $emptyOverrides $true
    Test-StoreManifest 'valid-store-v5-artifact-matrix' (New-BaseManifest 5) `
        $emptyOverrides $true '' @() 2 $true

    Test-StoreManifest 'store-provider-requires-artifact-matrix' $validProvider `
        $emptyOverrides $false 'Runtime provider Store versions must declare a platform artifact matrix'

    $mixedArtifactOverrides = [pscustomobject][ordered]@{
        artifacts = [object[]]@((New-StoreArtifact))
    }
    Test-StoreManifest 'store-mixed-artifact-representations' (New-BaseManifest 5) `
        $mixedArtifactOverrides $false 'cannot combine packageUrl with artifacts'

    $emptyArtifactOverrides = [pscustomobject][ordered]@{ artifacts = [object[]]@() }
    Test-StoreManifest 'store-empty-artifact-matrix' (New-BaseManifest 5) `
        $emptyArtifactOverrides $false 'Store artifact matrix cannot be empty' @() 2 $true

    $duplicateArtifactOverrides = [pscustomobject][ordered]@{
        artifacts = [object[]]@(
            (New-StoreArtifact 'windows-x64' 1),
            (New-StoreArtifact 'windows-x64' 2 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb')
        )
    }
    Test-StoreManifest 'store-duplicate-artifact-target' (New-BaseManifest 5) `
        $duplicateArtifactOverrides $false 'Duplicate plugin artifact target: windows-x64' @() 2 $true

    $architecturelessArtifactOverrides = [pscustomobject][ordered]@{
        artifacts = [object[]]@((New-StoreArtifact 'windows'))
    }
    Test-StoreManifest 'store-architectureless-artifact-target' (New-BaseManifest 5) `
        $architecturelessArtifactOverrides $false `
        'Plugin artifact target must include an architecture: windows' @() 2 $true

    foreach ($invalidArtifactUrl in @('http://example.test/plugin.npl', 'packages/plugin.npl')) {
        $artifact = New-StoreArtifact
        $artifact.packageUrl = $invalidArtifactUrl
        $artifactUrlOverrides = [pscustomobject][ordered]@{ artifacts = [object[]]@($artifact) }
        Test-StoreManifest "store-invalid-artifact-url-$($invalidArtifactUrl.GetHashCode())" `
            (New-BaseManifest 5) $artifactUrlOverrides $false `
            'Store artifact windows-x64 packageUrl must use HTTPS or loopback HTTP' @() 2 $true
    }

    foreach ($invalidArtifactSize in @('1', 1.5, 0, -1)) {
        $artifactSizeOverrides = [pscustomobject][ordered]@{
            artifacts = [object[]]@((New-StoreArtifact 'windows-x64' $invalidArtifactSize))
        }
        $expectedSizeMessage = if ($invalidArtifactSize -eq 0 -or $invalidArtifactSize -eq -1) {
            'Store artifact windows-x64 has an invalid size'
        } else {
            'Store artifact windows-x64 size must be an integer'
        }
        Test-StoreManifest "store-invalid-artifact-size-$invalidArtifactSize" (New-BaseManifest 5) `
            $artifactSizeOverrides $false $expectedSizeMessage @() 2 $true
    }

    foreach ($rawArtifactSize in @('1.0', '1e0', '18446744073709551617')) {
        Test-StoreManifest "store-raw-artifact-size-$($rawArtifactSize.Replace('.', '_'))" `
            (New-BaseManifest 5) $emptyOverrides $false `
            'Store artifact windows-x64 size must be an integer' @() 2 $true $rawArtifactSize
    }

    Test-StoreManifest 'store-execution-mode-mismatch' $validRust `
        ([pscustomobject][ordered]@{ executionMode = 'embedded' }) $false `
        'Store executionMode does not match plugin.json'
    Test-StoreManifest 'store-runtime-provider-pin-mismatch' $validRust `
        ([pscustomobject][ordered]@{ runtimeProvider = 'dev.hmclce.runtime.other' }) $false `
        'Store runtimeProvider does not match plugin.json'

    $nullStoreRuntimeProvider = [pscustomobject][ordered]@{ runtimeProvider = $null }
    Test-StoreManifest 'store-null-runtime-provider-package-omitted' (New-BaseManifest 5) `
        $nullStoreRuntimeProvider $false 'Store runtimeProvider must be a string'
    $packageNullRuntimeProvider = New-BaseManifest 5
    $packageNullRuntimeProvider | Add-Member -NotePropertyName 'runtimeProvider' -NotePropertyValue $null
    Test-StoreManifest 'store-null-runtime-provider-package-null' $packageNullRuntimeProvider `
        $nullStoreRuntimeProvider $false 'Store runtimeProvider must be a string'

    $differentDeclarations = [pscustomobject][ordered]@{}
    Add-ManifestArrayProperty $differentDeclarations 'providesRuntimes' `
        @((New-RuntimeDeclaration 'wasm'))
    Test-StoreManifest 'store-provided-runtimes-mismatch' $validProvider $differentDeclarations `
        $false 'Store providesRuntimes does not match plugin.json' @() 2 $true

    $orderedPlatformsManifest = New-BaseManifest 5
    $orderedPlatformsManifest.platforms = @('linux', 'windows-x64')
    Test-StoreManifest 'store-platform-order-equivalence' $orderedPlatformsManifest `
        ([pscustomobject][ordered]@{ platforms = @('windows-x64', 'linux') }) $true

    Test-StoreManifest 'store-v5-missing-runtime' (New-BaseManifest 5) $emptyOverrides $false `
        'Store pluginApiVersion 5 must declare runtime' @('runtime')
    Test-StoreManifest 'store-v5-missing-abi' (New-BaseManifest 5) $emptyOverrides $false `
        'Store pluginApiVersion 5 must declare abi' @('abi')
    Test-StoreManifest 'store-v5-missing-platforms-unrestricted' (New-BaseManifest 5) $emptyOverrides $true `
        '' @('platforms')

    Test-StoreManifest 'store-v5-runtime-mismatch' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ runtime = 'dotnet' }) $false `
        'Store runtime does not match plugin.json: dotnet'
    Test-StoreManifest 'store-v5-abi-mismatch' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ abi = 1 }) $false `
        'Store abi does not match plugin.json: 1'
    Test-StoreManifest 'store-v5-platforms-mismatch' $orderedPlatformsManifest `
        ([pscustomobject][ordered]@{ platforms = @('linux') }) $false `
        'Store platforms do not match plugin.json: linux'

    Test-StoreManifest 'store-v5-null-runtime' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ runtime = $null }) $false `
        'Store pluginApiVersion 5 runtime cannot be null'
    Test-StoreManifest 'store-v5-nonstring-runtime' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ runtime = 42 }) $false `
        'Store pluginApiVersion 5 runtime must be a string'
    Test-StoreManifest 'store-v5-noncanonical-runtime' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ runtime = ' Java ' }) $false `
        'Store pluginApiVersion 5 runtime identifier must be canonical:  Java '

    Test-StoreManifest 'store-v5-null-abi' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ abi = $null }) $false `
        'Store pluginApiVersion 5 abi cannot be null'
    Test-StoreManifest 'store-v5-noninteger-abi' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ abi = '2' }) $false `
        'Store pluginApiVersion 5 abi must be an integer: 2'
    Test-StoreManifest 'store-v5-unsupported-abi' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ abi = 3 }) $false `
        'Store pluginApiVersion 5 has unsupported abi: 3'

    Test-StoreManifest 'store-v5-null-platforms' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ platforms = $null }) $false `
        'Store pluginApiVersion 5 platforms cannot be null'
    Test-StoreManifest 'store-v5-nonarray-platforms' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ platforms = 'windows-x64' }) $false `
        'Store pluginApiVersion 5 platforms must be an array'
    Test-StoreManifest 'store-v5-noncanonical-platform' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ platforms = @('Windows-X64') }) $false `
        'Store pluginApiVersion 5 platform target must be canonical: Windows-X64'
    Test-StoreManifest 'store-v5-duplicate-platform' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ platforms = @('windows-x64', 'windows-x64') }) $false `
        'Store pluginApiVersion 5 has duplicate platform target: windows-x64'

    foreach ($field in @(
            'runtime', 'abi', 'platforms', 'pluginKind', 'executionMode',
            'runtimeProvider', 'providesRuntimes', 'artifacts')) {
        $value = if ($field -eq 'runtime') { $null } elseif ($field -eq 'abi') { 1 } else { @() }
        if ($field -eq 'pluginKind') { $value = 'normal' }
        if ($field -eq 'executionMode') { $value = 'embedded' }
        if ($field -eq 'runtimeProvider') { $value = 'dev.hmclce.runtime.provider' }
        $overrides = [pscustomobject][ordered]@{}
        $overrides | Add-Member -NotePropertyName $field -NotePropertyValue $value
        $expected = if ($field -in @('runtime', 'abi', 'platforms')) {
            "Store pluginApiVersion 4 cannot declare schema-v5 compatibility field: $field"
        } elseif ($field -eq 'artifacts') {
            'Store pluginApiVersion 4 cannot declare artifacts'
        } else {
            "Store pluginApiVersion 4 cannot declare runtime Provider field: $field"
        }
        Test-StoreManifest "store-v4-forbidden-$field" (New-BaseManifest 4) $overrides $false `
            $expected
    }

    Test-StoreManifest 'store-v5-missing-permissions' (New-BaseManifest 5) `
        $emptyOverrides $false 'Store pluginApiVersion 5 must declare permissions as an array' @('permissions')
    Test-StoreManifest 'store-v5-missing-required-permissions' (New-BaseManifest 5) `
        $emptyOverrides $false 'Store pluginApiVersion 5 must declare requiredPermissions as an array' `
        @('requiredPermissions')

    Test-StoreManifest 'overflow-store-schema-version' (New-BaseManifest 5) $emptyOverrides $false `
        'Store manifest schemaVersion is outside Int32 range: 2147483648' @() ([int64]2147483648)
    Test-StoreManifest 'overflow-store-plugin-api-version' (New-BaseManifest 5) `
        ([pscustomobject][ordered]@{ pluginApiVersion = [int64]2147483648 }) $false `
        'Store pluginApiVersion is outside Int32 range: 2147483648'

    foreach ($field in @(
            'runtime', 'abi', 'platforms', 'hooks', 'patches',
            'pluginKind', 'executionMode', 'runtimeProvider', 'providesRuntimes')) {
        $manifest = New-BaseManifest 4
        if ($field -eq 'runtime') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue 'java' }
        if ($field -eq 'abi') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue 1 }
        if ($field -eq 'platforms') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue @() }
        if ($field -eq 'hooks') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue @() }
        if ($field -eq 'patches') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue @() }
        if ($field -eq 'pluginKind') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue 'normal' }
        if ($field -eq 'executionMode') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue 'embedded' }
        if ($field -eq 'runtimeProvider') { $manifest | Add-Member -NotePropertyName $field -NotePropertyValue 'dev.hmclce.runtime.provider' }
        if ($field -eq 'providesRuntimes') { Add-ManifestArrayProperty $manifest $field @() }
        Test-Manifest "v5-$field-under-v4" $manifest $false `
            'Plugin manifest schemaVersion 4 cannot declare schema-v5 runtime capabilities'
    }

    foreach ($permission in @('launcher-hook', 'launcher-patch', 'launcher-core', 'jvm-raw', 'shell')) {
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
