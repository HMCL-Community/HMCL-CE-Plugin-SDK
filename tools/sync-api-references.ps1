param(
    [string]$HmclRepository = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'HMCL-CE')
)

$ErrorActionPreference = 'Stop'
$sdkRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $HmclRepository 'HMCL\src\main\java\org\jackhuang\hmcl\plugin'
$targetRoot = Join-Path $sdkRoot 'references\hmcl-plugin-api'

$files = @(
    'Plugin.java',
    'PluginContainer.java',
    'PluginContext.java',
    'PluginDependency.java',
    'PluginManifest.java',
    'PluginPermission.java',
    'PluginPermissionException.java',
    'PluginPermissionService.java',
    'PluginVersion.java',
    'PluginVersionConstraint.java',
    'store\PluginStoreItem.java',
    'store\PluginStoreManifest.java',
    'store\PluginStoreRegistry.java'
)

foreach ($relativePath in $files) {
    $source = Join-Path $sourceRoot $relativePath
    $target = Join-Path $targetRoot ([System.IO.Path]::GetFileName($relativePath))
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing HMCL API source: $source"
    }
    Copy-Item -LiteralPath $source -Destination $target -Force
}

Write-Host "Synchronized $($files.Count) HMCL plugin API reference files."
