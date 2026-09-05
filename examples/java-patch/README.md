# Java Patch Example

This plugin observes `FileUtils.getName(java.nio.file.Path)` after it returns and preserves the supplied result.

## Prerequisites

Use a source-built Aura Launcher JAR that exposes the current Patch API. A published beta asset is immutable; do not
assume it contains source-only Patch changes. The installed NPL needs the current exact-artifact `launcher-patch`
grant. An ordinary 27.1 Patch package may omit a certification receipt, but a present receipt is verified and can be
revoked.

A Patch-only declaration does not cause Aura's current bootstrap to relaunch with instrumentation. The launcher JAR
must be loaded as its own Java agent for this example to register actively. Without it, `register` returns
`PATCH_ENGINE_UNAVAILABLE`.

From the SDK root, set `HMCL_JAR`, then use the Aura wrapper configured through `AURA_GRADLE` or an installed Gradle 9.6.1:

```powershell
$sdkRoot = (Resolve-Path '.').Path
$exampleProject = Join-Path $sdkRoot 'examples\java-patch'
$env:HMCL_JAR = 'path-to-Aura-Launcher-27.1-next.jar'
$gradle = if ($env:AURA_GRADLE) { (Resolve-Path $env:AURA_GRADLE).Path } else { (Get-Command gradle -ErrorAction Stop).Source }
& $gradle -p $exampleProject test packageNpl --no-daemon --console=plain
& (Join-Path $sdkRoot 'tools\validate-npl.ps1') -Package (Join-Path $exampleProject 'build\npl\dev.hmclce.example.java.patch-v1.0.0.npl')
```

Install the generated NPL, approve `launcher-patch`, restart, then run the same packaged JAR as both agent and
application:

```powershell
$auraJar = (Resolve-Path $env:HMCL_JAR).Path
java "-javaagent:$auraJar" -jar $auraJar
```

The callback is observational and returns `PluginPatchResult.unchanged()`. It must not retain an invocation, a
Bridge handle, or a capability token after the callback ends.
