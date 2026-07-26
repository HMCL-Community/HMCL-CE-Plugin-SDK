<#
.SYNOPSIS
Creates an isolated, guaranteed-restricted HMCL Nex profile for regression testing.

.DESCRIPTION
Builds a throwaway HMCL home so the offline-account gate can be reproduced
deterministically, without touching the real profile at %APPDATA%\.hmcl.

The gate in AccountListPage lifts if ANY of these hold:
  1. -Dhmcl.offline.auth.restricted=false
  2. the property is "auto" AND LocaleUtils.IS_CHINA_MAINLAND
  3. userSettings().enableOfflineAccount is true

This factory neutralises (3) by writing enableOfflineAccount=false into the
isolated user home. The caller neutralises (1) and (2) by passing
-Dhmcl.offline.auth.restricted=true, which short-circuits the "auto" branch so
the machine's timezone/locale never enters the decision.

.PARAMETER Root
Directory to create the profile in. Removed and recreated if it exists.

.PARAMETER PluginNpl
Optional path to a .npl package. When supplied the plugin is pre-seeded as an
already-installed, already-granted plugin, skipping the interactive UI install.

.OUTPUTS
PSCustomObject with UserHome, LocalHome, Root and (if seeded) PluginId/PluginSha256.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Root,

    [Parameter()]
    [string] $PluginNpl
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (Test-Path -LiteralPath $Root) {
    Remove-Item -LiteralPath $Root -Recurse -Force
}

$userHome  = Join-Path $Root 'user'
$localHome = Join-Path $Root 'local'

foreach ($dir in @(
    (Join-Path $userHome  'config'),
    (Join-Path $userHome  'state'),
    (Join-Path $localHome 'config'),
    (Join-Path $localHome 'state'),
    (Join-Path $localHome 'plugins')
)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# The decisive bit of the RED baseline: the persisted opt-out must be false.
# UserSettings defaults this to false, but we write it explicitly so the
# baseline is self-documenting rather than relying on an implicit default.
$userSettings = [ordered]@{
    '$schema'             = 'https://schemas.glavo.site/hmcl/user-settings/1.0.0'
    'enableOfflineAccount' = $false
}
$userSettings | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $userHome 'config\user-settings.json') -Encoding UTF8

# Pre-accept the EULA/agreement prompts so the launcher lands directly on the
# main UI; otherwise the first-run modal blocks the accessibility probe.
$userState = [ordered]@{
    '$schema'                    = 'https://schemas.glavo.site/hmcl/user-state/1.0.0'
    'agreementVersion'           = 1
    'terracottaAgreementVersion' = 2
}
$userState | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $userHome 'state\user-state.json') -Encoding UTF8

$result = [ordered]@{
    Root      = (Resolve-Path -LiteralPath $Root).Path
    UserHome  = (Resolve-Path -LiteralPath $userHome).Path
    LocalHome = (Resolve-Path -LiteralPath $localHome).Path
}

if ($PSBoundParameters.ContainsKey('PluginNpl') -and $PluginNpl) {
    if (-not (Test-Path -LiteralPath $PluginNpl)) {
        throw "Plugin package not found: $PluginNpl"
    }

    # Read id/version/permissions straight out of the package so the grant
    # record can never drift from what is actually installed.
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $PluginNpl).Path)
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -eq 'plugin.json' }
        if (-not $entry) { throw "plugin.json missing from $PluginNpl" }
        $reader = New-Object System.IO.StreamReader($entry.Open())
        try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    } finally {
        $zip.Dispose()
    }

    $pluginId = $manifest.id
    $sha256   = (Get-FileHash -LiteralPath $PluginNpl -Algorithm SHA256).Hash.ToLowerInvariant()

    # Discovery expects <id>.npl, not the versioned build artifact name.
    Copy-Item -LiteralPath $PluginNpl `
              -Destination (Join-Path $localHome "plugins\$pluginId.npl") -Force

    # Grants are keyed by id and pinned to version + package digest, mirroring
    # what the UI install flow records.
    $permissions = @{
        schemaVersion = 1
        grants        = @{
            $pluginId = @(
                @{
                    version     = $manifest.version
                    sha256      = $sha256
                    permissions = @($manifest.permissions)
                }
            )
        }
    }
    $permissions | ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath (Join-Path $localHome 'plugin-permissions.json') -Encoding UTF8

    $states = @{
        enabled          = @($pluginId)
        pendingUninstall = @()
    }
    $states | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $localHome 'plugin-states.json') -Encoding UTF8

    $result['PluginId']     = $pluginId
    $result['PluginSha256'] = $sha256
}

[PSCustomObject]$result
