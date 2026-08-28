param(
    [Parameter(Mandatory = $true)]
    [string]$Package,
    [string]$StoreManifest
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-Condition([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Get-JsonProperty($Object, [string]$Name) {
    if ($null -eq $Object -or $null -eq $Object.PSObject) {
        return $null
    }
    return $Object.PSObject.Properties[$Name]
}

function Test-JsonInteger($Value) {
    return $Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64]
}

function ConvertTo-JsonInt32($Value, [string]$Field) {
    $numericValue = [decimal]$Value
    Assert-Condition (
        $numericValue -ge [int]::MinValue -and
        $numericValue -le [int]::MaxValue
    ) "$Field is outside Int32 range: $Value"
    return [int]$Value
}

function ConvertTo-JsonInt64($Value, [string]$Field) {
    $numericValue = [decimal]$Value
    Assert-Condition ($numericValue -ge [int64]::MinValue -and $numericValue -le [int64]::MaxValue) `
        "$Field is outside Int64 range: $Value"
    return [int64]$Value
}

function Test-CanonicalExecutableId($Value) {
    if ($Value -isnot [string]) {
        return $false
    }
    $id = [string]$Value
    if ($id -cnotmatch '^[a-z0-9][a-z0-9._-]{1,127}$' -or $id.EndsWith('.')) {
        return $false
    }
    $baseName = $id.Split('.')[0]
    return $baseName -cnotin @(
        'con', 'prn', 'aux', 'nul',
        'com1', 'com2', 'com3', 'com4', 'com5', 'com6', 'com7', 'com8', 'com9',
        'lpt1', 'lpt2', 'lpt3', 'lpt4', 'lpt5', 'lpt6', 'lpt7', 'lpt8', 'lpt9'
    )
}

function Test-ValidStoreArtifactUrl($Value) {
    if ($Value -isnot [string]) {
        return $false
    }
    $uri = $null
    if (-not [System.Uri]::TryCreate([string]$Value, [System.UriKind]::Absolute, [ref]$uri)) {
        return $false
    }
    $scheme = $uri.Scheme.ToLowerInvariant()
    $uriHost = $uri.Host.ToLowerInvariant()
    $loopbackHttp = $scheme -ceq 'http' -and
        $uriHost -cin @('localhost', '127.0.0.1', '::1', '[::1]')
    return -not [string]::IsNullOrWhiteSpace($uriHost) -and
        ($scheme -ceq 'https' -or $loopbackHttp)
}

function Get-CanonicalEnumSet(
        $Object,
        [string]$Field,
        [string[]]$KnownValues,
        [string]$Subject,
        [bool]$RequireNonEmpty) {
    $property = Get-JsonProperty $Object $Field
    Assert-Condition ($null -ne $property) "$Subject has no $Field"
    Assert-Condition ($null -ne $property.Value -and $property.Value -is [System.Array]) `
        "$Subject $Field must be an array"
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($value in @($property.Value)) {
        Assert-Condition ($value -is [string]) "$Subject $Field value must be a string"
        $token = [string]$value
        Assert-Condition ($KnownValues -icontains $token) "Unknown $Subject $Field value: $token"
        Assert-Condition ($token -ceq $token.ToLowerInvariant()) "$Subject $Field value must be canonical: $token"
        Assert-Condition ($seen.Add($token)) "Duplicate $Subject $Field value: $token"
    }
    if ($RequireNonEmpty) {
        Assert-Condition ($seen.Count -gt 0) "$Subject $Field set cannot be empty"
    }
    Write-Output -NoEnumerate $seen
}

function Get-RuntimeProviderDeclarations($Object, [string]$Subject) {
    $property = Get-JsonProperty $Object 'providesRuntimes'
    if ($null -eq $property) {
        return @()
    }
    Assert-Condition ($null -ne $property.Value -and $property.Value -is [System.Array]) `
        "Plugin providesRuntimes must be an array"
    $declarations = @()
    foreach ($value in @($property.Value)) {
        Assert-Condition ($null -ne $value) "$Subject provided runtime declaration cannot be null"
        Assert-Condition ($value -is [pscustomobject]) 'Runtime provider declaration must be an object'

        $runtimeProperty = Get-JsonProperty $value 'runtime'
        Assert-Condition ($null -ne $runtimeProperty -and $runtimeProperty.Value -is [string]) `
            'Runtime provider declaration runtime must be a string'
        $providedRuntime = [string]$runtimeProperty.Value
        $canonicalRuntime = $providedRuntime.Trim().ToLowerInvariant()
        Assert-Condition ($canonicalRuntime.Length -le 32 -and $canonicalRuntime -match '^[a-z0-9-]+$') `
            "Invalid runtime provider identifier: $providedRuntime"
        Assert-Condition ($providedRuntime -ceq $canonicalRuntime) `
            "Runtime provider identifier must be canonical: $providedRuntime"

        $abisProperty = Get-JsonProperty $value 'abis'
        Assert-Condition ($null -ne $abisProperty -and $null -ne $abisProperty.Value -and
            $abisProperty.Value -is [System.Array]) 'Runtime provider abis must be an array'
        $abis = [System.Collections.Generic.HashSet[int]]::new()
        foreach ($abiValue in @($abisProperty.Value)) {
            Assert-Condition (Test-JsonInteger $abiValue) 'Runtime provider abis must be an integer'
            $providerAbi = ConvertTo-JsonInt32 $abiValue 'Runtime provider abi'
            Assert-Condition ($providerAbi -gt 0) "Runtime provider ABI must be positive: $providerAbi"
            Assert-Condition ($abis.Add($providerAbi)) "Duplicate runtime provider ABI: $providerAbi"
        }
        Assert-Condition ($abis.Count -gt 0) 'Runtime provider ABI set cannot be empty'

        $bridgeAbiProperty = Get-JsonProperty $value 'bridgeAbi'
        Assert-Condition ($null -ne $bridgeAbiProperty -and (Test-JsonInteger $bridgeAbiProperty.Value)) `
            'Runtime provider bridgeAbi must be an integer'
        $bridgeAbi = ConvertTo-JsonInt32 $bridgeAbiProperty.Value 'Runtime provider bridgeAbi'
        Assert-Condition ($bridgeAbi -gt 0) "Runtime provider bridge ABI must be positive: $bridgeAbi"

        $executionModes = Get-CanonicalEnumSet $value 'executionModes' `
            @('embedded', 'isolated') 'runtime provider' $true
        $features = Get-CanonicalEnumSet $value 'features' `
            @('bridge', 'hooks', 'patches', 'raw-jvm', 'native') 'runtime provider' $false
        Assert-Condition ($features.Contains('bridge')) 'Runtime providers must implement bridge'
        $declarations += [pscustomobject]@{
            Runtime = $providedRuntime
            Abis = $abis
            BridgeAbi = $bridgeAbi
            ExecutionModes = $executionModes
            Features = $features
        }
    }
    return @($declarations)
}

function Get-RuntimeProviderDeclarationIdentity($Declaration) {
    return "$($Declaration.Runtime)|$(@($Declaration.Abis | Sort-Object) -join ',')|$($Declaration.BridgeAbi)|$(@($Declaration.ExecutionModes | Sort-Object) -join ',')|$(@($Declaration.Features | Sort-Object) -join ',')"
}

function Get-StoreCompatibilityContract($StoreVersion, [int]$PluginApiVersion) {
    $compatibilityFields = @('runtime', 'abi', 'platforms')
    if ($PluginApiVersion -eq 4) {
        foreach ($field in $compatibilityFields) {
            Assert-Condition ($null -eq (Get-JsonProperty $StoreVersion $field)) `
                "Store pluginApiVersion 4 cannot declare schema-v5 compatibility field: $field"
        }
        return [pscustomobject]@{ Runtime = 'java'; Abi = 1; Platforms = @() }
    }

    $subject = "Store pluginApiVersion $PluginApiVersion"
    $runtimeProperty = Get-JsonProperty $StoreVersion 'runtime'
    Assert-Condition ($null -ne $runtimeProperty) "$subject must declare runtime"
    Assert-Condition ($null -ne $runtimeProperty.Value) "$subject runtime cannot be null"
    if ($runtimeProperty.Value -isnot [string]) {
        $runtimeType = $runtimeProperty.Value.GetType().FullName
        $runtimeValue = $runtimeProperty.Value | ConvertTo-Json -Depth 10 -Compress
        throw "$subject runtime must be a string; found $runtimeType value $runtimeValue"
    }
    $runtime = [string]$runtimeProperty.Value
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($runtime)) "$subject runtime cannot be blank"
    $canonicalRuntime = $runtime.Trim().ToLowerInvariant()
    Assert-Condition (
        $canonicalRuntime.Length -le 32 -and
        $canonicalRuntime -match '^[a-z0-9-]+$'
    ) "$subject has invalid runtime identifier: $runtime"
    Assert-Condition ($runtime -ceq $canonicalRuntime) `
        "$subject runtime identifier must be canonical: $runtime"

    $abiProperty = Get-JsonProperty $StoreVersion 'abi'
    Assert-Condition ($null -ne $abiProperty) "$subject must declare abi"
    Assert-Condition ($null -ne $abiProperty.Value) "$subject abi cannot be null"
    Assert-Condition (Test-JsonInteger $abiProperty.Value) `
        "$subject abi must be an integer: $($abiProperty.Value)"
    $abi = ConvertTo-JsonInt32 $abiProperty.Value "$subject abi"
    Assert-Condition ($abi -in @(1, 2)) "$subject has unsupported abi: $abi"

    $platformProperty = Get-JsonProperty $StoreVersion 'platforms'
    $platformValues = @()
    if ($null -ne $platformProperty) {
        Assert-Condition ($null -ne $platformProperty.Value) "$subject platforms cannot be null"
        Assert-Condition ($platformProperty.Value -is [System.Array]) "$subject platforms must be an array"
        $platformValues = @($platformProperty.Value)
    }
    $knownOperatingSystems = @('windows', 'linux', 'macos', 'freebsd')
    $knownArchitectures = @('x86', 'x64', 'arm32', 'arm64', 'riscv64', 'loongarch64', 'mips64')
    $seenPlatforms = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($platformValue in $platformValues) {
        Assert-Condition ($null -ne $platformValue) "$subject platform target cannot be null"
        Assert-Condition ($platformValue -is [string]) "$subject platform target must be a string: $platformValue"
        $platform = [string]$platformValue
        $canonicalPlatform = $platform.Trim().ToLowerInvariant()
        $separator = $canonicalPlatform.IndexOf('-')
        if ($separator -lt 0) {
            $operatingSystem = $canonicalPlatform
            $architecture = $null
        } else {
            $operatingSystem = $canonicalPlatform.Substring(0, $separator)
            $architecture = $canonicalPlatform.Substring($separator + 1)
        }
        Assert-Condition (
            $operatingSystem -in $knownOperatingSystems -and
            ($null -eq $architecture -or $architecture -in $knownArchitectures)
        ) "$subject has invalid platform target: $platform"
        Assert-Condition ($platform -ceq $canonicalPlatform) `
            "$subject platform target must be canonical: $platform"
        Assert-Condition ($seenPlatforms.Add($canonicalPlatform)) `
            "$subject has duplicate platform target: $platform"
    }
    return [pscustomobject]@{
        Runtime = $canonicalRuntime
        Abi = $abi
        Platforms = @($seenPlatforms | Sort-Object)
    }
}

function Assert-SafeResourcePath([string]$Resource, [string]$Description) {
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($Resource)) "$Description must not be blank"
    Assert-Condition ($Resource -ceq $Resource.Trim()) "Invalid ${Description}: $Resource"
    Assert-Condition (
        -not $Resource.StartsWith('/') -and
        -not $Resource.EndsWith('/') -and
        -not $Resource.Contains('\') -and
        -not $Resource.Contains(':') -and
        -not $Resource.Contains('//')
    ) "Invalid ${Description}: $Resource"
    foreach ($component in $Resource.Split('/', [System.StringSplitOptions]::None)) {
        Assert-Condition ($component -ne '' -and $component -ne '.' -and $component -ne '..') "Invalid ${Description}: $Resource"
    }
}

function Find-Resource([System.IO.Compression.ZipArchive]$Archive, [string]$Resource) {
    $rootEntry = $Archive.GetEntry($Resource)
    if ($null -ne $rootEntry -and -not $rootEntry.FullName.EndsWith('/')) {
        return $true
    }

    foreach ($jarEntry in $Archive.Entries | Where-Object { $_.FullName.EndsWith('.jar', [System.StringComparison]::OrdinalIgnoreCase) }) {
        $memory = [System.IO.MemoryStream]::new()
        try {
            $input = $jarEntry.Open()
            try {
                $input.CopyTo($memory)
            } finally {
                $input.Dispose()
            }
            $memory.Position = 0
            $jar = [System.IO.Compression.ZipArchive]::new($memory, [System.IO.Compression.ZipArchiveMode]::Read, $true)
            try {
                $resourceEntry = $jar.GetEntry($Resource)
                if ($null -ne $resourceEntry -and -not $resourceEntry.FullName.EndsWith('/')) {
                    return $true
                }
            } finally {
                $jar.Dispose()
            }
        } finally {
            $memory.Dispose()
        }
    }
    return $false
}

function Assert-IsolatedRustProviderArtifacts(
        [System.IO.Compression.ZipArchive]$Archive,
        [object[]]$Platforms,
        [object[]]$RuntimeDeclarations) {
    $isolatedRustDeclarations = @($RuntimeDeclarations | Where-Object {
        $_.Runtime -ceq 'rust' -and $_.ExecutionModes.Contains('isolated')
    })
    if ($isolatedRustDeclarations.Count -eq 0) {
        return
    }

    foreach ($declaration in $isolatedRustDeclarations) {
        Assert-Condition (-not $declaration.Features.Contains('raw-jvm')) `
            'Isolated runtime providers cannot expose raw-jvm'
    }

    $artifactsByPlatform = @{
        'windows-x64' = @('hmcl_rust_host_native.dll', 'hmcl-rust-host-process.exe')
        'windows-arm64' = @('hmcl_rust_host_native.dll', 'hmcl-rust-host-process.exe')
        'linux-x64' = @('libhmcl_rust_host_native.so', 'hmcl-rust-host-process')
        'linux-arm64' = @('libhmcl_rust_host_native.so', 'hmcl-rust-host-process')
        'macos-x64' = @('libhmcl_rust_host_native.dylib', 'hmcl-rust-host-process')
        'macos-arm64' = @('libhmcl_rust_host_native.dylib', 'hmcl-rust-host-process')
    }
    Assert-Condition ($Platforms.Count -gt 0) `
        'Isolated Rust runtime providers must declare at least one concrete platform'
    $packagedPlatformCount = 0
    foreach ($platformValue in $Platforms) {
        $platform = [string]$platformValue
        Assert-Condition ($artifactsByPlatform.ContainsKey($platform)) `
            "Unsupported isolated Rust runtime provider platform: $platform"
        $nativeRoot = "native/$platform"
        $jniPath = "$nativeRoot/$($artifactsByPlatform[$platform][0])"
        $processPath = "$nativeRoot/$($artifactsByPlatform[$platform][1])"
        $jniEntry = $Archive.GetEntry($jniPath)
        $processEntry = $Archive.GetEntry($processPath)
        $hasJni = $null -ne $jniEntry -and -not $jniEntry.FullName.EndsWith('/')
        $hasProcess = $null -ne $processEntry -and -not $processEntry.FullName.EndsWith('/')
        if ($hasJni -or $hasProcess) {
            Assert-Condition $hasJni `
                "Isolated Rust runtime provider is missing JNI artifact: $jniPath"
            Assert-Condition $hasProcess `
                "Isolated Rust runtime provider is missing process Host artifact: $processPath"
            $packagedPlatformCount++
        }
    }
    Assert-Condition ($packagedPlatformCount -gt 0) `
        'Isolated Rust runtime provider package must contain artifacts for at least one declared platform'
}

$resolvedPackage = (Resolve-Path -LiteralPath $Package).Path
Assert-Condition ($resolvedPackage.EndsWith('.npl', [System.StringComparison]::OrdinalIgnoreCase)) 'Plugin package must use the .npl extension'
$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedPackage)
try {
    $totalSize = [int64]0
    $entryCount = 0
    $entryNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $archive.Entries) {
        $entryCount++
        Assert-Condition ($entryCount -le 10000) 'Package contains more than 10000 archive entries'
        $entryName = $entry.FullName
        Assert-Condition ($entryNames.Add($entryName)) "Duplicate archive entry: $entryName"
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($entryName)) 'Package contains a blank archive path'
        Assert-Condition (
            -not $entryName.StartsWith('/') -and
            -not $entryName.Contains('\') -and
            -not $entryName.Contains(':') -and
            -not $entryName.Contains('//')
        ) "Unsafe archive path: $entryName"
        $pathWithoutDirectoryMarker = $entryName.TrimEnd('/')
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($pathWithoutDirectoryMarker)) "Unsafe archive path: $entryName"
        foreach ($segment in $pathWithoutDirectoryMarker.Split('/', [System.StringSplitOptions]::None)) {
            Assert-Condition ($segment -ne '' -and $segment -ne '.' -and $segment -ne '..') "Unsafe archive path: $entryName"
        }
        $totalSize += $entry.Length
        Assert-Condition ($totalSize -le 536870912) 'Package expands beyond 512 MiB'
    }

    $manifestEntries = @($archive.Entries | Where-Object { $_.FullName -ceq 'plugin.json' })
    Assert-Condition ($manifestEntries.Count -eq 1) 'Exactly one plugin.json is required at the package root'
    $manifestEntry = $manifestEntries[0]
    Assert-Condition (-not $manifestEntry.FullName.EndsWith('/')) 'plugin.json must be a regular archive entry'
    Assert-Condition ($manifestEntry.Length -le 1048576) 'plugin.json exceeds 1 MiB'

    $reader = [System.IO.StreamReader]::new($manifestEntry.Open(), [System.Text.Encoding]::UTF8)
    try {
        $manifest = $reader.ReadToEnd() | ConvertFrom-Json
    } finally {
        $reader.Dispose()
    }

    Assert-Condition ($manifest -is [pscustomobject]) 'plugin.json root must be an object'
    $schemaVersionProperty = Get-JsonProperty $manifest 'schemaVersion'
    Assert-Condition ($null -ne $schemaVersionProperty -and (Test-JsonInteger $schemaVersionProperty.Value)) `
        'Plugin schemaVersion must be an integer'
    $schemaVersion = ConvertTo-JsonInt32 $schemaVersionProperty.Value 'Plugin schemaVersion'
    Assert-Condition ($schemaVersion -in @(4, 5)) `
        "Aura only supports schemaVersion 4 or 5 plugins; found schemaVersion $schemaVersion"
    Assert-Condition ($manifest.id -is [string] -and $manifest.id -match '^[A-Za-z0-9][A-Za-z0-9._-]{1,127}$') "Invalid plugin id: $($manifest.id)"
    foreach ($field in @('name', 'version', 'type', 'entrypoint')) {
        $property = Get-JsonProperty $manifest $field
        Assert-Condition ($null -ne $property -and $property.Value -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) "Missing or invalid plugin field: $field"
    }

    $schemaFiveFields = @(
        'runtime', 'abi', 'platforms', 'hooks', 'patches',
        'pluginKind', 'executionMode', 'runtimeProvider', 'providesRuntimes'
    )
    if ($schemaVersion -eq 4) {
        foreach ($field in $schemaFiveFields) {
            Assert-Condition ($null -eq (Get-JsonProperty $manifest $field)) `
                'Plugin manifest schemaVersion 4 cannot declare schema-v5 runtime capabilities'
        }
    }

    $platformValues = @()
    $hookValues = @()
    $patchValues = @()
    $pluginKind = 'normal'
    $executionMode = 'embedded'
    $runtimeProvider = $null
    $providedRuntimes = @()
    if ($schemaVersion -eq 5) {
        $runtimeProperty = Get-JsonProperty $manifest 'runtime'
        Assert-Condition ($null -ne $runtimeProperty) 'Schema-v5 plugin manifest must declare runtime'
        Assert-Condition ($null -ne $runtimeProperty.Value) 'Plugin manifest runtime cannot be null'
        if ($runtimeProperty.Value -isnot [string]) {
            $runtimeType = $runtimeProperty.Value.GetType().FullName
            $runtimeValue = $runtimeProperty.Value | ConvertTo-Json -Depth 10 -Compress
            throw "Plugin manifest runtime must be a string; found $runtimeType value $runtimeValue"
        }
        $runtime = [string]$runtimeProperty.Value
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($runtime)) `
            'Plugin manifest runtime cannot be blank'
        $canonicalRuntime = $runtime.Trim().ToLowerInvariant()
        Assert-Condition (
            $canonicalRuntime.Length -le 32 -and
            $canonicalRuntime -match '^[a-z0-9-]+$'
        ) "Invalid plugin runtime identifier: $runtime"
        Assert-Condition ($runtime -ceq $canonicalRuntime) `
            "Plugin runtime identifier must be canonical: $runtime"

        $abiProperty = Get-JsonProperty $manifest 'abi'
        Assert-Condition ($null -ne $abiProperty) 'Schema-v5 plugin manifest must declare abi'
        Assert-Condition ($null -ne $abiProperty.Value) 'Plugin manifest abi cannot be null'
        Assert-Condition (Test-JsonInteger $abiProperty.Value) `
            "Plugin manifest abi must be an integer: $($abiProperty.Value)"
        $abi = ConvertTo-JsonInt32 $abiProperty.Value 'Plugin manifest abi'
        Assert-Condition ($abi -in @(1, 2)) "Unsupported plugin manifest abi: $abi"

        $platformProperty = Get-JsonProperty $manifest 'platforms'
        if ($null -ne $platformProperty) {
            Assert-Condition ($null -ne $platformProperty.Value) 'Plugin platforms cannot be null'
            Assert-Condition ($platformProperty.Value -is [System.Array]) 'Plugin platforms must be an array'
            $platformValues = @($platformProperty.Value)
        }
        $knownOperatingSystems = @('windows', 'linux', 'macos', 'freebsd')
        $knownArchitectures = @('x86', 'x64', 'arm32', 'arm64', 'riscv64', 'loongarch64', 'mips64')
        $seenPlatforms = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($platformValue in $platformValues) {
            Assert-Condition ($null -ne $platformValue) 'Plugin platform target cannot be null'
            Assert-Condition ($platformValue -is [string]) "Plugin platform target must be a string: $platformValue"
            $platform = [string]$platformValue
            $canonicalPlatform = $platform.Trim().ToLowerInvariant()
            $separator = $canonicalPlatform.IndexOf('-')
            if ($separator -lt 0) {
                $operatingSystem = $canonicalPlatform
                $architecture = $null
            } else {
                $operatingSystem = $canonicalPlatform.Substring(0, $separator)
                $architecture = $canonicalPlatform.Substring($separator + 1)
            }
            Assert-Condition (
                $operatingSystem -in $knownOperatingSystems -and
                ($null -eq $architecture -or $architecture -in $knownArchitectures)
            ) "Invalid plugin platform target: $platform"
            Assert-Condition ($platform -ceq $canonicalPlatform) `
                "Plugin platform target must be canonical: $platform"
            Assert-Condition ($seenPlatforms.Add($canonicalPlatform)) `
                "Duplicate plugin platform target: $platform"
        }

        $hookProperty = Get-JsonProperty $manifest 'hooks'
        if ($null -ne $hookProperty) {
            Assert-Condition ($null -ne $hookProperty.Value) 'Plugin hooks cannot be null'
            Assert-Condition ($hookProperty.Value -is [System.Array]) 'Plugin hooks must be an array'
            $hookValues = @($hookProperty.Value)
        }
        $knownHooks = @(
            'before-download', 'after-download',
            'before-game-launch', 'after-game-launch',
            'before-login', 'after-login',
            'before-instance-create', 'after-instance-create',
            'before-mod-install', 'after-mod-install',
            'before-settings-load', 'after-settings-load'
        )
        $seenHooks = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($hookValue in $hookValues) {
            Assert-Condition ($null -ne $hookValue) 'Plugin hook point cannot be null or unknown'
            Assert-Condition ($hookValue -is [string] -and $hookValue -cin $knownHooks) `
                "Unknown plugin hook point: $hookValue"
            $hook = [string]$hookValue
            Assert-Condition ($seenHooks.Add($hook)) "Duplicate plugin hook point: $hook"
        }

        $patchProperty = Get-JsonProperty $manifest 'patches'
        if ($null -ne $patchProperty) {
            Assert-Condition ($null -ne $patchProperty.Value) 'Plugin patches cannot be null'
            Assert-Condition ($patchProperty.Value -is [System.Array]) 'Plugin patches must be an array'
            $patchValues = @($patchProperty.Value)
        }
        $seenPatches = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($patch in $patchValues) {
            Assert-Condition ($null -ne $patch -and $patch -is [pscustomobject]) `
                'Plugin patch declaration cannot be null or malformed'
            $targetProperty = Get-JsonProperty $patch 'target'
            $target = if ($null -ne $targetProperty -and $targetProperty.Value -is [string]) {
                [string]$targetProperty.Value
            } else {
                $null
            }
            Assert-Condition (
                $null -ne $target -and
                $target -match '^[a-zA-Z_$][a-zA-Z0-9_$]*(\.[a-zA-Z_$][a-zA-Z0-9_$]*)+$'
            ) "Invalid patch target class: $target"

            $methodProperty = Get-JsonProperty $patch 'method'
            $method = if ($null -ne $methodProperty -and $methodProperty.Value -is [string]) {
                [string]$methodProperty.Value
            } else {
                $null
            }
            Assert-Condition ($null -ne $method -and $method -match '^[a-zA-Z_$][a-zA-Z0-9_$]*$') `
                "Invalid patch method name: $method"

            $typeProperty = Get-JsonProperty $patch 'type'
            $patchType = if ($null -ne $typeProperty -and $typeProperty.Value -is [string]) {
                [string]$typeProperty.Value
            } else {
                $null
            }
            if ($null -eq $patchType) {
                throw "Missing patch type for $target.$method"
            }
            Assert-Condition ($patchType -cin @('before', 'after', 'replace')) `
                "Unknown plugin patch type: $patchType"

            $parametersProperty = Get-JsonProperty $patch 'parameters'
            Assert-Condition ($null -ne $parametersProperty -and $null -ne $parametersProperty.Value) `
                "Missing patch parameters for $target.$method"
            Assert-Condition ($parametersProperty.Value -is [System.Array]) `
                "Patch parameters must be an array for $target.$method"
            $parameterValues = @($parametersProperty.Value)
            foreach ($parameterValue in $parameterValues) {
                Assert-Condition (
                    $parameterValue -is [string] -and
                    -not [string]::IsNullOrWhiteSpace([string]$parameterValue)
                ) "Patch parameter cannot be null or blank for $target.$method"
            }

            $patchIdentity = [pscustomobject][ordered]@{
                target = $target
                method = $method
                type = $patchType
                parameters = @($parameterValues | ForEach-Object { [string]$_ })
            }
            $patchKey = $patchIdentity | ConvertTo-Json -Depth 5 -Compress
            Assert-Condition ($seenPatches.Add($patchKey)) `
                "Duplicate plugin patch declaration: $target.$method"
        }

        $pluginKindProperty = Get-JsonProperty $manifest 'pluginKind'
        if ($null -ne $pluginKindProperty) {
            Assert-Condition ($pluginKindProperty.Value -is [string]) 'Plugin pluginKind must be a string'
            $pluginKind = [string]$pluginKindProperty.Value
            Assert-Condition ($pluginKind -cin @('normal', 'runtime-provider') -and
                $pluginKind -ceq $pluginKind.ToLowerInvariant()) `
                "Plugin pluginKind must be canonical: $pluginKind"
        }

        $executionModeProperty = Get-JsonProperty $manifest 'executionMode'
        if ($null -ne $executionModeProperty) {
            Assert-Condition ($executionModeProperty.Value -is [string]) 'Plugin executionMode must be a string'
            $executionMode = [string]$executionModeProperty.Value
            Assert-Condition ($executionMode -cin @('embedded', 'isolated') -and
                $executionMode -ceq $executionMode.ToLowerInvariant()) `
                "Plugin executionMode must be canonical: $executionMode"
        }

        $runtimeProviderProperty = Get-JsonProperty $manifest 'runtimeProvider'
        if ($null -ne $runtimeProviderProperty) {
            Assert-Condition ($null -eq $runtimeProviderProperty.Value -or
                $runtimeProviderProperty.Value -is [string]) 'Plugin runtimeProvider must be a string or null'
            $runtimeProvider = $runtimeProviderProperty.Value
            if ($null -ne $runtimeProvider) {
                Assert-Condition (Test-CanonicalExecutableId $runtimeProvider) `
                    "Invalid runtime provider plugin ID: $runtimeProvider"
            }
        }
        $providedRuntimes = @(Get-RuntimeProviderDeclarations $manifest 'Plugin')

        if ($pluginKind -ceq 'normal') {
            Assert-Condition ($providedRuntimes.Count -eq 0) 'Normal plugins cannot provide runtimes'
            if ($executionMode -ceq 'isolated' -and
                    @($manifest.permissions) -ccontains 'jvm-raw') {
                throw 'Isolated runtime requirements cannot require raw-jvm'
            }
        } else {
            Assert-Condition ($runtime -ceq 'java') 'Runtime-provider plugins must use the java runtime'
            Assert-Condition ($executionMode -ceq 'embedded') `
                'Runtime-provider plugins must use embedded Java bootstrap execution'
            Assert-Condition ($null -eq $runtimeProvider) `
                'Runtime-provider plugins cannot pin another runtime provider'
            Assert-Condition ($providedRuntimes.Count -gt 0) `
                'Runtime-provider plugins must provide at least one runtime'
            $providedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
            foreach ($declaration in $providedRuntimes) {
                Assert-Condition ($declaration.Runtime -cne 'java') `
                    'Runtime-provider plugins cannot provide the built-in java runtime'
                Assert-Condition ($providedIds.Add($declaration.Runtime)) `
                    "Duplicate provided runtime: $($declaration.Runtime)"
            }
        }
    }

    Assert-IsolatedRustProviderArtifacts $archive $platformValues $providedRuntimes

    $pluginType = ([string]$manifest.type).ToLowerInvariant()
    Assert-Condition ($pluginType -in @('java', 'kotlin')) `
        "Unsupported plugin type: $pluginType. Aura accepts Java and Kotlin packages."
    $entrypoint = [string]$manifest.entrypoint
    if ($schemaVersion -eq 4 -or $runtime -ceq 'java') {
        $entrypointResource = $entrypoint.Replace('.', '/') + '.class'
        Assert-SafeResourcePath $entrypointResource 'Java/Kotlin entrypoint'
        Assert-Condition (Find-Resource $archive $entrypointResource) "Java/Kotlin entrypoint class not found: $entrypoint"
    } else {
        Assert-SafeResourcePath $entrypoint 'runtime payload entrypoint'
        $runtimeEntry = $archive.GetEntry($entrypoint)
        Assert-Condition ($null -ne $runtimeEntry -and -not $runtimeEntry.FullName.EndsWith('/')) `
            "Runtime payload entrypoint not found: $entrypoint"
    }

    $permissionProperty = Get-JsonProperty $manifest 'permissions'
    Assert-Condition ($null -ne $permissionProperty -and $permissionProperty.Value -is [System.Array]) `
        "schemaVersion $schemaVersion requires an explicit permissions array"

    $knownPermissions = @(
        'filesystem', 'network', 'process', 'account',
        'game-launch', 'launcher-ui', 'mixin', 'clipboard', 'native-code',
        'launcher-hook', 'launcher-patch', 'launcher-core', 'jvm-raw', 'shell'
    )
    $permissions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $permissionValues = if ($null -eq $permissionProperty) { @() } else { @($permissionProperty.Value) }
    foreach ($permission in $permissionValues) {
        Assert-Condition ($permission -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$permission)) 'Plugin permissions must be non-blank strings'
        $permissionId = [string]$permission
        Assert-Condition ($permissionId -in $knownPermissions) "Unknown plugin permission: $permissionId"
        Assert-Condition ($permissions.Add($permissionId)) "Duplicate plugin permission: $permissionId"
    }

    $versionTokenPattern = '[vV]?\d+(?:\.[^.\-+\s,<>=*]+)*(?:-[^.\-+\s,<>=*]+(?:[.-][^.\-+\s,<>=*]+)*)?(?:\+[^+\s,<>=*]+)?'
    $constraintPattern = "^\s*(?:\*|=?\s*$versionTokenPattern|(?:<=|>=|<|>)\s*$versionTokenPattern(?:(?:\s+|\s*,\s*)(?:<=|>=|<|>)\s*$versionTokenPattern)*)\s*$"
    $requiredPermissionProperty = Get-JsonProperty $manifest 'requiredPermissions'
    Assert-Condition ($null -ne $requiredPermissionProperty -and $requiredPermissionProperty.Value -is [System.Array]) `
        "schemaVersion $schemaVersion requires an explicit requiredPermissions array"
    $requiredPermissions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $requiredPermissionValues = if ($null -eq $requiredPermissionProperty) { @() } else { @($requiredPermissionProperty.Value) }
    foreach ($permission in $requiredPermissionValues) {
        Assert-Condition ($permission -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$permission)) 'Required plugin permissions must be non-blank strings'
        $permissionId = [string]$permission
        Assert-Condition ($permissionId -in $knownPermissions) "Unknown required plugin permission: $permissionId"
        Assert-Condition ($requiredPermissions.Add($permissionId)) "Duplicate required plugin permission: $permissionId"
        Assert-Condition ($permissions.Contains($permissionId)) "Required permission was not declared in permissions: $permissionId"
    }
    if ($permissions.Contains('mixin')) {
        Assert-Condition ($requiredPermissions.Contains('mixin')) `
            "schemaVersion $schemaVersion plugins must make mixin a required permission"
    }
    if ($schemaVersion -eq 4 -and @($permissions | Where-Object {
            $_ -in @('launcher-hook', 'launcher-patch', 'launcher-core', 'jvm-raw', 'shell')
        }).Count -gt 0) {
        throw 'Plugin manifest schemaVersion 4 cannot declare schema-v5 launcher permissions'
    }
    if ($hookValues.Count -gt 0 -and
            (-not $permissions.Contains('launcher-hook') -or -not $requiredPermissions.Contains('launcher-hook'))) {
        throw 'Plugin hooks require launcher-hook in permissions and requiredPermissions'
    }
    if ($patchValues.Count -gt 0 -and
            (-not $permissions.Contains('launcher-patch') -or -not $requiredPermissions.Contains('launcher-patch'))) {
        throw 'Plugin patches require launcher-patch in permissions and requiredPermissions'
    }
    if ($pluginKind -ceq 'runtime-provider') {
        $requiresNativeCode = @($providedRuntimes | Where-Object {
            $_.Features.Contains('native') -or $_.Features.Contains('raw-jvm')
        }).Count -gt 0
        if ($requiresNativeCode -and -not $permissions.Contains('native-code')) {
            throw 'Native runtime providers must declare permission native-code'
        }
    }

    $launcherVersionProperty = Get-JsonProperty $manifest 'launcherVersion'
    $minimumLauncherVersionProperty = Get-JsonProperty $manifest 'minLauncherVersion'
    Assert-Condition ($null -ne $launcherVersionProperty -and $launcherVersionProperty.Value -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$launcherVersionProperty.Value)) `
        "schemaVersion $schemaVersion requires launcherVersion"
    Assert-Condition ([string]$launcherVersionProperty.Value -match $constraintPattern) "Invalid launcherVersion constraint: $($launcherVersionProperty.Value)"
    Assert-Condition ($null -eq $minimumLauncherVersionProperty) `
        "schemaVersion $schemaVersion uses launcherVersion and cannot declare minLauncherVersion"

    $dependencies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $dependencyProperty = Get-JsonProperty $manifest 'dependencies'
    if ($null -ne $dependencyProperty) {
        Assert-Condition ($dependencyProperty.Value -is [System.Array]) 'Plugin dependencies must be an array'
    }
    $dependencyValues = if ($null -eq $dependencyProperty) { @() } else { @($dependencyProperty.Value) }
    foreach ($dependency in $dependencyValues) {
        Assert-Condition ($null -ne $dependency) 'Plugin dependencies cannot contain null'
        if ($dependency -is [string]) {
            $dependencyId = [string]$dependency
            $dependencyVersion = '*'
        } else {
            Assert-Condition ($dependency -is [pscustomobject]) 'Plugin dependencies must be strings or objects'
            $dependencyIdProperty = Get-JsonProperty $dependency 'id'
            Assert-Condition ($null -ne $dependencyIdProperty -and $dependencyIdProperty.Value -is [string]) 'Plugin dependency id must be a string'
            $dependencyId = [string]$dependencyIdProperty.Value
            $dependencyVersionProperty = Get-JsonProperty $dependency 'version'
            if ($null -eq $dependencyVersionProperty) {
                $dependencyVersion = '*'
            } else {
                Assert-Condition ($dependencyVersionProperty.Value -is [string]) "Plugin dependency version for $dependencyId must be a string"
                $dependencyVersion = if ([string]::IsNullOrWhiteSpace([string]$dependencyVersionProperty.Value)) { '*' } else { [string]$dependencyVersionProperty.Value }
            }
        }
        Assert-Condition ($dependencyId -match '^[A-Za-z0-9][A-Za-z0-9._-]{1,127}$') "Invalid dependency id: $dependencyId"
        Assert-Condition ($dependencyId -cne [string]$manifest.id) 'A plugin cannot depend on itself'
        Assert-Condition ($dependencies.Add($dependencyId)) "Duplicate dependency: $dependencyId"
        Assert-Condition ($dependencyVersion -match $constraintPattern) "Invalid dependency version constraint for ${dependencyId}: $dependencyVersion"
    }

    $mixinProperty = Get-JsonProperty $manifest 'mixins'
    if ($null -ne $mixinProperty -and $null -ne $mixinProperty.Value) {
        Assert-Condition ($mixinProperty.Value -is [System.Array]) 'Plugin mixins must be an array'
    }
    $mixinConfigs = if ($null -eq $mixinProperty -or $null -eq $mixinProperty.Value) { @() } else { @($mixinProperty.Value) }
    if ($mixinConfigs.Count -gt 0) {
        Assert-Condition ($permissions.Contains('mixin')) `
            "schemaVersion $schemaVersion plugins with Mixins must declare permission mixin"
        Assert-Condition ($requiredPermissions.Contains('mixin')) `
            "schemaVersion $schemaVersion plugins with Mixins must require permission mixin"
    }
    $seenMixinConfigs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($mixinConfigValue in $mixinConfigs) {
        Assert-Condition ($mixinConfigValue -is [string]) 'Mixin configuration names must be strings'
        $mixinConfig = [string]$mixinConfigValue
        Assert-SafeResourcePath $mixinConfig 'Mixin config path'
        Assert-Condition ($mixinConfig.EndsWith('.json', [System.StringComparison]::Ordinal)) "Invalid Mixin config path: $mixinConfig"
        Assert-Condition ($seenMixinConfigs.Add($mixinConfig)) "Duplicate Mixin config path: $mixinConfig"
        Assert-Condition (Find-Resource $archive $mixinConfig) "Mixin config resource not found: $mixinConfig"
    }
} finally {
    $archive.Dispose()
}

$hash = (Get-FileHash -LiteralPath $resolvedPackage -Algorithm SHA256).Hash.ToLowerInvariant()
$size = (Get-Item -LiteralPath $resolvedPackage).Length

if (-not [string]::IsNullOrWhiteSpace($StoreManifest)) {
    $resolvedStoreManifest = (Resolve-Path -LiteralPath $StoreManifest).Path
    $store = Get-Content -LiteralPath $resolvedStoreManifest -Raw | ConvertFrom-Json
    Assert-Condition ($store -is [pscustomobject]) 'Store manifest root must be an object'
    $storeSchemaVersionProperty = Get-JsonProperty $store 'schemaVersion'
    Assert-Condition ($null -ne $storeSchemaVersionProperty -and (Test-JsonInteger $storeSchemaVersionProperty.Value)) `
        'Store manifest schemaVersion must be an integer'
    $storeSchemaVersion = ConvertTo-JsonInt32 $storeSchemaVersionProperty.Value 'Store manifest schemaVersion'
    Assert-Condition ($storeSchemaVersion -in @(1, 2)) 'Store manifest schemaVersion must be 1 or 2'
    Assert-Condition ([string]$store.id -ceq [string]$manifest.id) 'Store manifest id does not match plugin.json'
    Assert-Condition ($store.versions -is [System.Array]) 'Store manifest versions must be an array'

    $matchingVersions = @($store.versions | Where-Object { [string]$_.version -ceq [string]$manifest.version })
    Assert-Condition ($matchingVersions.Count -eq 1) "Store manifest must contain exactly one version $($manifest.version)"
    $storeVersion = $matchingVersions[0]
    $storePluginApiVersionProperty = Get-JsonProperty $storeVersion 'pluginApiVersion'
    Assert-Condition (
        $null -ne $storePluginApiVersionProperty -and
        (Test-JsonInteger $storePluginApiVersionProperty.Value)
    ) 'Store pluginApiVersion must be an integer'
    $storePluginApiVersion = ConvertTo-JsonInt32 `
        $storePluginApiVersionProperty.Value 'Store pluginApiVersion'
    Assert-Condition ($storePluginApiVersion -eq $schemaVersion) 'Store pluginApiVersion does not match plugin.json schemaVersion'

    $artifactProperty = Get-JsonProperty $storeVersion 'artifacts'
    $legacyPackageFields = @('packageUrl', 'sha256', 'size')
    if ($storePluginApiVersion -eq 4) {
        Assert-Condition ($null -eq $artifactProperty) 'Store pluginApiVersion 4 cannot declare artifacts'
    }
    if ($null -ne $artifactProperty) {
        foreach ($field in $legacyPackageFields) {
            Assert-Condition ($null -eq (Get-JsonProperty $storeVersion $field)) `
                "Store pluginApiVersion 5 cannot combine $field with artifacts"
        }
        Assert-Condition ($null -ne $artifactProperty.Value -and
            $artifactProperty.Value -is [System.Array]) 'Store artifacts must be an array'
        $artifactValues = @($artifactProperty.Value)
        Assert-Condition ($artifactValues.Count -gt 0) 'Store artifact matrix cannot be empty'
        $artifactTargets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        $matchingArtifacts = 0
        foreach ($artifact in $artifactValues) {
            Assert-Condition ($null -ne $artifact -and $artifact -is [pscustomobject]) `
                'Store artifact must be an object'
            $targetProperty = Get-JsonProperty $artifact 'platform'
            Assert-Condition ($null -ne $targetProperty -and $targetProperty.Value -is [string]) `
                'Store artifact platform must be a string'
            $target = [string]$targetProperty.Value
            $canonicalTarget = $target.Trim().ToLowerInvariant()
            $separator = $canonicalTarget.IndexOf('-')
            Assert-Condition ($separator -gt 0 -and $separator -lt $canonicalTarget.Length - 1) `
                "Plugin artifact target must include an architecture: $target"
            $targetOs = $canonicalTarget.Substring(0, $separator)
            $targetArch = $canonicalTarget.Substring($separator + 1)
            Assert-Condition ($targetOs -in @('windows', 'linux', 'macos', 'freebsd') -and
                $targetArch -in @('x86', 'x64', 'arm32', 'arm64', 'riscv64', 'loongarch64', 'mips64')) `
                "Invalid plugin artifact target: $target"
            Assert-Condition ($target -ceq $canonicalTarget) `
                "Plugin artifact target must be canonical: $target"
            Assert-Condition ($artifactTargets.Add($target)) "Duplicate plugin artifact target: $target"

            $urlProperty = Get-JsonProperty $artifact 'packageUrl'
            Assert-Condition ($null -ne $urlProperty -and $urlProperty.Value -is [string] -and
                -not [string]::IsNullOrWhiteSpace([string]$urlProperty.Value)) `
                "Store artifact $target must declare packageUrl as a string"
            Assert-Condition (Test-ValidStoreArtifactUrl $urlProperty.Value) `
                "Store artifact $target packageUrl must use HTTPS or loopback HTTP"
            $shaProperty = Get-JsonProperty $artifact 'sha256'
            Assert-Condition ($null -ne $shaProperty -and $shaProperty.Value -is [string] -and
                [string]$shaProperty.Value -cmatch '^[0-9a-f]{64}$') `
                "Store artifact $target has an invalid SHA-256 checksum"
            $sizeProperty = Get-JsonProperty $artifact 'size'
            Assert-Condition ($null -ne $sizeProperty -and (Test-JsonInteger $sizeProperty.Value)) `
                "Store artifact $target size must be an integer"
            $artifactSize = ConvertTo-JsonInt64 $sizeProperty.Value "Store artifact $target size"
            Assert-Condition ($artifactSize -gt 0) "Store artifact $target has an invalid size"
            if ([string]$shaProperty.Value -ceq $hash -and $artifactSize -eq $size) {
                $matchingArtifacts++
            }
        }
        Assert-Condition ($matchingArtifacts -eq 1) `
            'Store artifact matrix must contain exactly one artifact matching the package bytes'
    } else {
        foreach ($field in $legacyPackageFields) {
            $property = Get-JsonProperty $storeVersion $field
            Assert-Condition ($null -ne $property) "Store version must declare $field"
        }
        Assert-Condition ($storeVersion.packageUrl -is [string] -and
            -not [string]::IsNullOrWhiteSpace([string]$storeVersion.packageUrl)) `
            'Store packageUrl must be a non-blank string'
        Assert-Condition ($storeVersion.sha256 -is [string] -and
            [string]$storeVersion.sha256 -cmatch '^[0-9a-f]{64}$') 'Store SHA-256 must be lower-case hexadecimal'
        Assert-Condition (Test-JsonInteger $storeVersion.size) 'Store size must be an integer'
        $storeSize = ConvertTo-JsonInt64 $storeVersion.size 'Store size'
        Assert-Condition ($storeSize -gt 0) 'Store size must be positive'
        Assert-Condition ([string]$storeVersion.sha256 -ceq $hash) 'Store SHA-256 does not match package bytes'
        Assert-Condition ($storeSize -eq $size) 'Store size does not match package bytes'
    }

    $storeCompatibility = Get-StoreCompatibilityContract $storeVersion $storePluginApiVersion
    $packageRuntime = if ($schemaVersion -eq 4) { 'java' } else { $runtime }
    $packageAbi = if ($schemaVersion -eq 4) { 1 } else { $abi }
    $packagePlatforms = if ($schemaVersion -eq 4) { @() } else { @($platformValues | Sort-Object) }
    Assert-Condition ($storeCompatibility.Runtime -ceq $packageRuntime) `
        "Store runtime does not match plugin.json: $($storeCompatibility.Runtime)"
    Assert-Condition ($storeCompatibility.Abi -eq $packageAbi) `
        "Store abi does not match plugin.json: $($storeCompatibility.Abi)"
    $storePlatformIdentity = @($storeCompatibility.Platforms) -join "`n"
    $packagePlatformIdentity = @($packagePlatforms) -join "`n"
    $storePlatformDescription = if ($storePlatformIdentity.Length -eq 0) {
        '<unrestricted>'
    } else {
        @($storeCompatibility.Platforms) -join ', '
    }
    Assert-Condition ($storePlatformIdentity -ceq $packagePlatformIdentity) `
        "Store platforms do not match plugin.json: $storePlatformDescription"

    $storeProviderFields = @('pluginKind', 'executionMode', 'runtimeProvider', 'providesRuntimes')
    if ($storePluginApiVersion -eq 4) {
        foreach ($field in $storeProviderFields) {
            Assert-Condition ($null -eq (Get-JsonProperty $storeVersion $field)) `
                "Store pluginApiVersion 4 cannot declare runtime Provider field: $field"
        }
    } else {
        $storePluginKind = 'normal'
        $storePluginKindProperty = Get-JsonProperty $storeVersion 'pluginKind'
        if ($null -ne $storePluginKindProperty) {
            Assert-Condition ($storePluginKindProperty.Value -is [string]) `
                'Store pluginKind must be a string'
            $storePluginKind = [string]$storePluginKindProperty.Value
            Assert-Condition ($storePluginKind -cin @('normal', 'runtime-provider') -and
                $storePluginKind -ceq $storePluginKind.ToLowerInvariant()) `
                "Store pluginKind must be canonical: $storePluginKind"
        }
        $storeExecutionMode = 'embedded'
        $storeExecutionModeProperty = Get-JsonProperty $storeVersion 'executionMode'
        if ($null -ne $storeExecutionModeProperty) {
            Assert-Condition ($storeExecutionModeProperty.Value -is [string]) `
                'Store executionMode must be a string'
            $storeExecutionMode = [string]$storeExecutionModeProperty.Value
            Assert-Condition ($storeExecutionMode -cin @('embedded', 'isolated') -and
                $storeExecutionMode -ceq $storeExecutionMode.ToLowerInvariant()) `
                "Store executionMode must be canonical: $storeExecutionMode"
        }
        $storeRuntimeProvider = $null
        $storeRuntimeProviderProperty = Get-JsonProperty $storeVersion 'runtimeProvider'
        if ($null -ne $storeRuntimeProviderProperty) {
            Assert-Condition ($storeRuntimeProviderProperty.Value -is [string]) `
                'Store runtimeProvider must be a string'
            $storeRuntimeProvider = [string]$storeRuntimeProviderProperty.Value
            Assert-Condition (Test-CanonicalExecutableId $storeRuntimeProvider) `
                "Invalid Store runtime provider plugin ID: $storeRuntimeProvider"
        }
        $storeProvidedRuntimes = @(Get-RuntimeProviderDeclarations $storeVersion 'Store')
        Assert-Condition ($storePluginKind -ceq $pluginKind) 'Store pluginKind does not match plugin.json'
        Assert-Condition ($storeExecutionMode -ceq $executionMode) 'Store executionMode does not match plugin.json'
        Assert-Condition ([string]$storeRuntimeProvider -ceq [string]$runtimeProvider) `
            'Store runtimeProvider does not match plugin.json'
        $packageDeclarationIds = @($providedRuntimes | ForEach-Object {
            Get-RuntimeProviderDeclarationIdentity $_
        } | Sort-Object)
        $storeDeclarationIds = @($storeProvidedRuntimes | ForEach-Object {
            Get-RuntimeProviderDeclarationIdentity $_
        } | Sort-Object)
        Assert-Condition (($packageDeclarationIds -join "`n") -ceq ($storeDeclarationIds -join "`n")) `
            'Store providesRuntimes does not match plugin.json'
        if ($storePluginKind -ceq 'runtime-provider') {
            Assert-Condition ($null -ne $artifactProperty) `
                'Runtime provider Store versions must declare a platform artifact matrix'
        }
    }

    $storePermissionProperty = Get-JsonProperty $storeVersion 'permissions'
    Assert-Condition ($null -ne $storePermissionProperty -and $storePermissionProperty.Value -is [System.Array]) `
        "Store pluginApiVersion $storePluginApiVersion must declare permissions as an array"
    $packagePermissions = @($permissionValues | ForEach-Object { [string]$_ } | Sort-Object)
    $storePermissions = if ($null -eq $storePermissionProperty) { @() } else { @($storePermissionProperty.Value | ForEach-Object { [string]$_ } | Sort-Object) }
    Assert-Condition (($packagePermissions -join "`n") -ceq ($storePermissions -join "`n")) 'Store permissions do not match plugin.json'

    $storeRequiredPermissionProperty = Get-JsonProperty $storeVersion 'requiredPermissions'
    Assert-Condition ($null -ne $storeRequiredPermissionProperty -and $storeRequiredPermissionProperty.Value -is [System.Array]) `
        "Store pluginApiVersion $storePluginApiVersion must declare requiredPermissions as an array"
    $packageRequiredPermissions = @($requiredPermissionValues | ForEach-Object { [string]$_ } | Sort-Object)
    $storeRequiredPermissions = if ($null -eq $storeRequiredPermissionProperty) { @() } else { @($storeRequiredPermissionProperty.Value | ForEach-Object { [string]$_ } | Sort-Object) }
    Assert-Condition (($packageRequiredPermissions -join "`n") -ceq ($storeRequiredPermissions -join "`n")) 'Store requiredPermissions do not match plugin.json'

    Assert-Condition ([string]$storeVersion.launcherVersion -ceq [string]$manifest.launcherVersion) 'Store launcherVersion does not match plugin.json'

    $normalizeDependency = {
        param($Dependency)
        if ($Dependency -is [string]) {
            return "${Dependency}|*"
        }
        $dependencyVersion = if ([string]::IsNullOrWhiteSpace([string]$Dependency.version)) { '*' } else { [string]$Dependency.version }
        return "$([string]$Dependency.id)|$dependencyVersion"
    }
    $storeDependencyProperty = Get-JsonProperty $storeVersion 'dependencies'
    if ($null -ne $storeDependencyProperty) {
        Assert-Condition ($storeDependencyProperty.Value -is [System.Array]) 'Store dependencies must be an array'
    }
    $storeDependencyValues = if ($null -eq $storeDependencyProperty) { @() } else { @($storeDependencyProperty.Value) }
    $packageDependencies = @($dependencyValues | ForEach-Object $normalizeDependency | Sort-Object)
    $storeDependencies = @($storeDependencyValues | ForEach-Object $normalizeDependency | Sort-Object)
    Assert-Condition (($packageDependencies -join "`n") -ceq ($storeDependencies -join "`n")) 'Store dependencies do not match plugin.json'

    if ($mixinConfigs.Count -gt 0 -or $permissions.Contains('mixin')) {
        Assert-Condition ($storeVersion.requiresRestart -is [bool] -and [bool]$storeVersion.requiresRestart) 'Store version with Mixins must require restart'
    }
}

Write-Host "Valid NPL: $resolvedPackage"
Write-Host "SHA-256: $hash"
Write-Host "Size: $size bytes"
