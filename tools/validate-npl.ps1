param(
    [Parameter(Mandatory = $true)]
    [string]$Package
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-Condition([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Find-Resource([System.IO.Compression.ZipArchive]$Archive, [string]$Resource) {
    if ($null -ne $Archive.GetEntry($Resource)) {
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
                if ($null -ne $jar.GetEntry($Resource)) {
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
$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedPackage)
try {
    $totalSize = [int64]0
    foreach ($entry in $archive.Entries) {
        $segments = $entry.FullName.Replace('\', '/').Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
        Assert-Condition (-not $entry.FullName.StartsWith('/') -and -not ($segments -contains '..')) "Unsafe archive path: $($entry.FullName)"
        $totalSize += $entry.Length
        Assert-Condition ($totalSize -le 536870912) 'Package expands beyond 512 MiB'
    }

    $manifestEntry = $archive.GetEntry('plugin.json')
    Assert-Condition ($null -ne $manifestEntry) 'plugin.json is required at the package root'
    Assert-Condition ($manifestEntry.Length -le 1048576) 'plugin.json exceeds 1 MiB'

    $reader = [System.IO.StreamReader]::new($manifestEntry.Open(), [System.Text.Encoding]::UTF8)
    try {
        $manifest = $reader.ReadToEnd() | ConvertFrom-Json
    } finally {
        $reader.Dispose()
    }

    $schemaVersion = if ($null -eq $manifest.schemaVersion) { 1 } else { [int]$manifest.schemaVersion }
    Assert-Condition ($schemaVersion -ge 1 -and $schemaVersion -le 2) "Unsupported schemaVersion: $schemaVersion"
    Assert-Condition ($manifest.id -match '^[A-Za-z0-9][A-Za-z0-9._-]{1,127}$') "Invalid plugin id: $($manifest.id)"
    foreach ($field in @('name', 'version', 'type', 'entrypoint')) {
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($manifest.$field)) "Missing plugin field: $field"
    }

    $pluginType = ([string]$manifest.type).ToLowerInvariant()
    Assert-Condition ($pluginType -in @('java', 'kotlin', 'javascript')) "Unsupported plugin type: $pluginType"
    if ($pluginType -eq 'javascript') {
        Assert-Condition (Find-Resource $archive ([string]$manifest.entrypoint)) "JavaScript entrypoint not found: $($manifest.entrypoint)"
    }

    $dependencies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($dependency in (@($manifest.dependencies) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        Assert-Condition ($dependency -match '^[A-Za-z0-9][A-Za-z0-9._-]{1,127}$') "Invalid dependency id: $dependency"
        Assert-Condition ($dependency -ne $manifest.id) 'A plugin cannot depend on itself'
        Assert-Condition ($dependencies.Add([string]$dependency)) "Duplicate dependency: $dependency"
    }

    foreach ($mixinConfig in (@($manifest.mixins) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        Assert-Condition ($pluginType -ne 'javascript') 'JavaScript plugins cannot declare Mixins'
        Assert-Condition ($mixinConfig -match '^[^/\\](?!.*\.\./).+\.json$') "Invalid Mixin config path: $mixinConfig"
        Assert-Condition (Find-Resource $archive ([string]$mixinConfig)) "Mixin config resource not found: $mixinConfig"
    }
} finally {
    $archive.Dispose()
}

$hash = (Get-FileHash -LiteralPath $resolvedPackage -Algorithm SHA256).Hash.ToLowerInvariant()
$size = (Get-Item -LiteralPath $resolvedPackage).Length
Write-Host "Valid NPL: $resolvedPackage"
Write-Host "SHA-256: $hash"
Write-Host "Size: $size bytes"
