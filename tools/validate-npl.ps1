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

function Assert-SafeResourcePath([string]$Resource, [string]$Description) {
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($Resource)) "$Description must not be blank"
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
    $schemaVersion = [int]$schemaVersionProperty.Value
    Assert-Condition ($schemaVersion -in @(4, 5)) `
        "HMCL CE only supports schemaVersion 4 or 5 plugins; found schemaVersion $schemaVersion"
    Assert-Condition ($manifest.id -is [string] -and $manifest.id -match '^[A-Za-z0-9][A-Za-z0-9._-]{1,127}$') "Invalid plugin id: $($manifest.id)"
    foreach ($field in @('name', 'version', 'type', 'entrypoint')) {
        $property = Get-JsonProperty $manifest $field
        Assert-Condition ($null -ne $property -and $property.Value -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) "Missing or invalid plugin field: $field"
    }

    $schemaFiveFields = @('runtime', 'abi', 'platforms', 'hooks', 'patches')
    if ($schemaVersion -eq 4) {
        foreach ($field in $schemaFiveFields) {
            Assert-Condition ($null -eq (Get-JsonProperty $manifest $field)) `
                'Plugin manifest schemaVersion 4 cannot declare schema-v5 runtime capabilities'
        }
    }

    $platformValues = @()
    $hookValues = @()
    $patchValues = @()
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
        $abi = [int]$abiProperty.Value
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
    }

    $pluginType = ([string]$manifest.type).ToLowerInvariant()
    Assert-Condition ($pluginType -in @('java', 'kotlin', 'csharp')) "Unsupported plugin type: $pluginType. HMCL CE accepts Java, Kotlin, and C# Companion packages."
    $entrypoint = [string]$manifest.entrypoint
    if ($pluginType -eq 'csharp') {
        Assert-Condition ($entrypoint -ceq 'companion/extension.json') 'C# Companion entrypoint must be companion/extension.json'
        $extensionManifestEntry = $archive.GetEntry('companion/extension.json')
        Assert-Condition ($null -ne $extensionManifestEntry -and -not $extensionManifestEntry.FullName.EndsWith('/')) 'C# Companion package must contain companion/extension.json'
        $extensionReader = [System.IO.StreamReader]::new($extensionManifestEntry.Open(), [System.Text.Encoding]::UTF8)
        try {
            $extensionManifest = $extensionReader.ReadToEnd() | ConvertFrom-Json
        } finally {
            $extensionReader.Dispose()
        }
        Assert-Condition ($extensionManifest.id -ceq $manifest.id) 'C# Companion package and extension IDs do not match'
        Assert-Condition ($extensionManifest.version -ceq $manifest.version) 'C# Companion package and extension versions do not match'
        Assert-Condition ($extensionManifest.entryAssembly -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$extensionManifest.entryAssembly)) 'C# Companion extension entryAssembly is required'
        Assert-SafeResourcePath ([string]$extensionManifest.entryAssembly) 'C# Companion entry assembly'
        Assert-Condition ($null -ne $archive.GetEntry("companion/$($extensionManifest.entryAssembly)")) "C# Companion entry assembly not found: $($extensionManifest.entryAssembly)"
    } else {
        $entrypointResource = $entrypoint.Replace('.', '/') + '.class'
        Assert-SafeResourcePath $entrypointResource 'Java/Kotlin entrypoint'
        Assert-Condition (Find-Resource $archive $entrypointResource) "Java/Kotlin entrypoint class not found: $entrypoint"
    }

    $permissionProperty = Get-JsonProperty $manifest 'permissions'
    Assert-Condition ($null -ne $permissionProperty -and $permissionProperty.Value -is [System.Array]) `
        "schemaVersion $schemaVersion requires an explicit permissions array"

    $knownPermissions = @(
        'filesystem', 'network', 'process', 'account',
        'game-launch', 'launcher-ui', 'mixin', 'clipboard', 'native-code',
        'launcher-hook', 'launcher-patch'
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
    if ($schemaVersion -eq 4 -and
            ($permissions.Contains('launcher-hook') -or $permissions.Contains('launcher-patch'))) {
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
    Assert-Condition ([int]$store.schemaVersion -in @(1, 2)) 'Store manifest schemaVersion must be 1 or 2'
    Assert-Condition ([string]$store.id -ceq [string]$manifest.id) 'Store manifest id does not match plugin.json'
    Assert-Condition ($store.versions -is [System.Array]) 'Store manifest versions must be an array'

    $matchingVersions = @($store.versions | Where-Object { [string]$_.version -ceq [string]$manifest.version })
    Assert-Condition ($matchingVersions.Count -eq 1) "Store manifest must contain exactly one version $($manifest.version)"
    $storeVersion = $matchingVersions[0]
    $storePluginApiVersion = [int]$storeVersion.pluginApiVersion
    Assert-Condition ($storePluginApiVersion -eq $schemaVersion) 'Store pluginApiVersion does not match plugin.json schemaVersion'
    Assert-Condition ([string]$storeVersion.sha256 -ceq $hash) 'Store SHA-256 does not match package bytes'
    Assert-Condition ([int64]$storeVersion.size -eq $size) 'Store size does not match package bytes'

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
