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
    $schemaVersion = if ($null -eq $schemaVersionProperty) { 1 } else { [int]$schemaVersionProperty.Value }
    Assert-Condition ($schemaVersion -eq 4) "HMCL Nex only supports schemaVersion 4 plugins; found schemaVersion $schemaVersion"
    Assert-Condition ($manifest.id -is [string] -and $manifest.id -match '^[A-Za-z0-9][A-Za-z0-9._-]{1,127}$') "Invalid plugin id: $($manifest.id)"
    foreach ($field in @('name', 'version', 'type', 'entrypoint')) {
        $property = Get-JsonProperty $manifest $field
        Assert-Condition ($null -ne $property -and $property.Value -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) "Missing or invalid plugin field: $field"
    }

    $pluginType = ([string]$manifest.type).ToLowerInvariant()
    Assert-Condition ($pluginType -in @('java', 'kotlin', 'javascript')) "Unsupported plugin type: $pluginType"
    $entrypoint = [string]$manifest.entrypoint
    if ($pluginType -eq 'javascript') {
        Assert-SafeResourcePath $entrypoint 'JavaScript entrypoint'
        Assert-Condition (Find-Resource $archive $entrypoint) "JavaScript entrypoint not found: $entrypoint"
    } else {
        $entrypointResource = $entrypoint.Replace('.', '/') + '.class'
        Assert-SafeResourcePath $entrypointResource 'Java/Kotlin entrypoint'
        Assert-Condition (Find-Resource $archive $entrypointResource) "Java/Kotlin entrypoint class not found: $entrypoint"
    }

    $permissionProperty = Get-JsonProperty $manifest 'permissions'
    Assert-Condition ($null -ne $permissionProperty -and $permissionProperty.Value -is [System.Array]) 'schemaVersion 4 requires an explicit permissions array'

    $knownPermissions = @(
        'filesystem', 'network', 'process', 'account',
        'game-launch', 'launcher-ui', 'mixin', 'clipboard', 'native-code'
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
    Assert-Condition ($null -ne $requiredPermissionProperty -and $requiredPermissionProperty.Value -is [System.Array]) 'schemaVersion 4 requires an explicit requiredPermissions array'
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
        Assert-Condition ($requiredPermissions.Contains('mixin')) 'schemaVersion 4 plugins must make mixin a required permission'
    }

    $launcherVersionProperty = Get-JsonProperty $manifest 'launcherVersion'
    $minimumLauncherVersionProperty = Get-JsonProperty $manifest 'minLauncherVersion'
    Assert-Condition ($null -ne $launcherVersionProperty -and $launcherVersionProperty.Value -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$launcherVersionProperty.Value)) 'schemaVersion 4 requires launcherVersion'
    Assert-Condition ([string]$launcherVersionProperty.Value -match $constraintPattern) "Invalid launcherVersion constraint: $($launcherVersionProperty.Value)"
    Assert-Condition ($null -eq $minimumLauncherVersionProperty) 'schemaVersion 4 uses launcherVersion and cannot declare minLauncherVersion'

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
        Assert-Condition ($permissions.Contains('mixin')) 'schemaVersion 4 plugins with Mixins must declare permission mixin'
        Assert-Condition ($requiredPermissions.Contains('mixin')) 'schemaVersion 4 plugins with Mixins must require permission mixin'
    }
    $seenMixinConfigs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($mixinConfigValue in $mixinConfigs) {
        Assert-Condition ($mixinConfigValue -is [string]) 'Mixin configuration names must be strings'
        $mixinConfig = [string]$mixinConfigValue
        Assert-Condition ($pluginType -ne 'javascript') 'JavaScript plugins cannot declare Mixins'
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
    Assert-Condition ([int]$storeVersion.pluginApiVersion -eq $schemaVersion) 'Store pluginApiVersion does not match plugin.json schemaVersion'
    Assert-Condition ([string]$storeVersion.sha256 -ceq $hash) 'Store SHA-256 does not match package bytes'
    Assert-Condition ([int64]$storeVersion.size -eq $size) 'Store size does not match package bytes'

    $storePermissionProperty = Get-JsonProperty $storeVersion 'permissions'
    Assert-Condition ($null -ne $storePermissionProperty -and $storePermissionProperty.Value -is [System.Array]) 'Store API-v4 versions must declare permissions as an array'
    $packagePermissions = @($permissionValues | ForEach-Object { [string]$_ } | Sort-Object)
    $storePermissions = if ($null -eq $storePermissionProperty) { @() } else { @($storePermissionProperty.Value | ForEach-Object { [string]$_ } | Sort-Object) }
    Assert-Condition (($packagePermissions -join "`n") -ceq ($storePermissions -join "`n")) 'Store permissions do not match plugin.json'

    $storeRequiredPermissionProperty = Get-JsonProperty $storeVersion 'requiredPermissions'
    Assert-Condition ($null -ne $storeRequiredPermissionProperty -and $storeRequiredPermissionProperty.Value -is [System.Array]) 'Store API-v4 version must declare requiredPermissions as an array'
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
