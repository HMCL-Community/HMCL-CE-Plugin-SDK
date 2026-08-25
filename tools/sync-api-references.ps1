param(
    [string]$HmclRepository
)

$ErrorActionPreference = 'Stop'
$sdkRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($HmclRepository)) {
    $sdkCheckoutRoot = $sdkRoot
    if ($null -ne (Get-Command git -ErrorAction SilentlyContinue)) {
        $gitCommonDirectory = (& git -C $sdkRoot rev-parse --path-format=absolute --git-common-dir 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitCommonDirectory)) {
            $sdkCheckoutRoot = Split-Path -Parent $gitCommonDirectory.Trim()
        }
    }
    $HmclRepository = Join-Path (Split-Path -Parent (Split-Path -Parent $sdkCheckoutRoot)) 'HMCL-CE'
}
$sourceRoot = Join-Path $HmclRepository 'HMCL\src\main\java\org\jackhuang\hmcl\plugin'
$targetRoot = Join-Path $sdkRoot 'references\hmcl-plugin-api'

$files = @(
    'Plugin.java',
    'PluginCapabilityLevel.java',
    'PluginContainer.java',
    'PluginContext.java',
    'PluginDataObject.java',
    'PluginDataValue.java',
    'PluginDependency.java',
    'PluginHookEvent.java',
    'PluginHookPoint.java',
    'PluginHookResult.java',
    'PluginKind.java',
    'PluginManifest.java',
    'PluginPatchDeclaration.java',
    'PluginPermission.java',
    'PluginPermissionException.java',
    'PluginPermissionService.java',
    'PluginPermissionTier.java',
    'PluginSecretAccess.java',
    'PluginVersion.java',
    'PluginVersionConstraint.java',
    'bridge\BridgeDispatcher.java',
    'bridge\BridgeError.java',
    'bridge\BridgeHandle.java',
    'bridge\BridgeHandleRegistry.java',
    'bridge\BridgeValue.java',
    'bridge\PluginCapabilitySession.java',
    'bridge\PluginCapabilityToken.java',
    'bridge\PluginPermissionAuthority.java',
    'runtime\JavaRuntimeProvider.java',
    'runtime\PluginAbi.java',
    'runtime\PluginCompatibilityRequirements.java',
    'runtime\PluginExecutionMode.java',
    'runtime\PluginPlatformTarget.java',
    'runtime\PluginRuntimeTypes.java',
    'runtime\RuntimeFeature.java',
    'runtime\RuntimePayloadContext.java',
    'runtime\RuntimePayloadHandle.java',
    'runtime\RuntimeProvider.java',
    'runtime\RuntimeProviderBinding.java',
    'runtime\RuntimeProviderDeclaration.java',
    'runtime\RuntimeProviderDescriptor.java',
    'runtime\RuntimeProviderRegistration.java',
    'runtime\RuntimeProviderRegistry.java',
    'runtime\RuntimeRequirement.java',
    'store\PluginInstallPlan.java',
    'store\PluginStoreArtifact.java',
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
