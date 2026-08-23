<#
.SYNOPSIS
Launches HMCL CE against an isolated profile with the offline gate forced ON.

.DESCRIPTION
Starts the launcher with:
  -Dhmcl.home=<profile>\user   redirects global user config
  -Dhmcl.dir=<profile>\local   redirects workspace config + plugins
  -Dhmcl.offline.auth.restricted=true

The third flag is what makes the baseline deterministic. Forcing "true"
short-circuits the "auto" branch in AccountListPage's static initialiser, so
IS_CHINA_MAINLAND (timezone / locale / Win32 GeoID) never participates and the
result does not depend on where the test machine happens to be.

stdout is captured because the plugin's mixin prints its marker line there;
that transcript is the GREEN arm's proof the injection actually executed.

.PARAMETER Profile
Object returned by New-RestrictedProfile.ps1.

.PARAMETER HmclJar
Path to the HMCL jar under test.

.PARAMETER LogDir
Directory for stdout/stderr transcripts.

.PARAMETER Tag
Short label distinguishing arms, e.g. "red" or "green".

.OUTPUTS
PSCustomObject with Process, StdOut, StdErr paths.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [psobject] $Profile,
    [Parameter(Mandatory = $true)] [string]   $HmclJar,
    [Parameter(Mandatory = $true)] [string]   $LogDir,
    [Parameter(Mandatory = $true)] [string]   $Tag
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $HmclJar)) {
    throw "HMCL jar not found: $HmclJar"
}
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$stdout = Join-Path $LogDir "$Tag.out.log"
$stderr = Join-Path $LogDir "$Tag.err.log"

$jvmArgs = @(
    "-Dhmcl.home=$($Profile.UserHome)"
    "-Dhmcl.dir=$($Profile.LocalHome)"
    '-Dhmcl.offline.auth.restricted=true'
    '-jar'
    $HmclJar
)

Write-Verbose "java $($jvmArgs -join ' ')"

$process = Start-Process -FilePath 'java' `
                         -ArgumentList $jvmArgs `
                         -RedirectStandardOutput $stdout `
                         -RedirectStandardError  $stderr `
                         -PassThru

[PSCustomObject]@{
    Process = $process
    Pid     = $process.Id
    StdOut  = $stdout
    StdErr  = $stderr
    Tag     = $Tag
}
