# 插件快速开始

本分支的示例生成 schema-v5 包并面向 Aura Launcher `next`。Schema v5 是语言中立的 runtime、ABI 与 platform
合同；当前示例只是使用内置 `java` provider 的 Java/Kotlin/Mixin 基线。SDK `schema-v4` 仍是稳定、默认分支，
Aura Launcher `next` 也仍接受 schema-v4 包。

## 复制 Java 示例

```powershell
Copy-Item -Recurse examples/java-helloworld my-aura-plugin
$aura = Resolve-Path $env:AURA_LAUNCHER_SOURCE
$env:HMCL_JAR = (Get-ChildItem "$aura/AuraLauncher/build/libs/Aura-Launcher-*.jar" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
& "$aura/gradlew.bat" -p my-aura-plugin clean packageNpl
```

## 配置清单

```json
{
  "schemaVersion": 5,
  "id": "com.example.hmclce.plugin",
  "name": "Aura Plugin",
  "version": "1.0.0",
  "type": "java",
  "runtime": "java",
  "abi": 2,
  "entrypoint": "com.example.hmclce.PluginMain",
  "dependencies": [],
  "permissions": ["launcher-ui"],
  "requiredPermissions": [],
  "launcherVersion": ">=26.8"
}
```

Kotlin 基线示例把 `type` 改为 `kotlin`，`runtime` 仍是 `java`，入口仍然是完整 JVM 类名。
`platforms` 可以省略或设为 `[]` 表示不限制平台；非空值必须是规范的 `os` 或 `os-arch` 标识。
HarmonyOS PC 使用独立的 `harmonyos-arm64` 标识。Aura Launcher 可在该目标缺少原生制品时单向选择
`linux-arm64`，但 HarmonyOS 制品不会匹配 Linux。该兼容路径尚未在 HarmonyOS PC 真机验证。

## 外部运行时边界

Aura Launcher `next` 仅内置 `java` provider。以下外部 Host 已独立发布，均需单独安装和更新：

- [Aura Rust Runtime Host](https://github.com/Egg-China/Aura-Rust-Runtime-Host)
- [Aura .NET Runtime Host](https://github.com/Egg-China/Aura-DotNet-Runtime-Host)
- [Aura QuickJS Runtime Host](https://github.com/Egg-China/Aura-QuickJS-Runtime-Host)
- [Aura Wasm Runtime Host](https://github.com/Egg-China/Aura-Wasm-Runtime-Host)

Python 与其他原生 payload 仍需尚未发布的对应 provider。

Rust isolated Hook 从 [独立 Host 仓库的 launch-hook 示例](https://github.com/Egg-China/Aura-Rust-Runtime-Host/tree/main/examples/launch-hook) 开始。它使用 ABI 1、固定
`dev.hmclce.runtime.rust-host`、声明 `before-game-launch`，并通过清单自动要求 Provider 的
`bridge` 与 `hooks` 能力。Host NPL 和 payload NPL 必须分别构建、安装与更新。

## 验证并安装

```powershell
./tools/validate-npl.ps1 -Package ./build/npl/com.example.hmclce.plugin-v1.0.0.npl
```

在 Aura Launcher `next` 的插件管理页安装包、确认权限并重启。首次安装和更新均不会在当前进程执行新插件。

## Mixin 插件

从 `examples/java-mixin` 开始。清单需要 `mixins`、`permissions: ["mixin"]` 与
`requiredPermissions: ["mixin"]`。启用、禁用、更新和卸载 Mixin 插件均需要重启。

## Hook 与 Patch 声明

Schema v5 可以声明 Hook 与 Patch，并分别要求 `launcher-hook`、`launcher-patch` 同时列入可选和必需权限。
当前 `next` 会分发已支持的游戏启动 Hook；其他 Hook 仍是声明合同。Patch 声明会被校验和暴露，但当前
没有字节码执行引擎。

## 发布

给仓库添加 Topic `aura-launcher`。当前 `store/github-release-workflow.yml` 面向普通 Java 单制品版本，Store 条目使用
版本级 `packageUrl`、`sha256` 与 `size`。Runtime Host 使用六个必需平台加可选实验性
`harmonyos-arm64` 的 `artifacts[]` 矩阵，不能直接套用这条
单制品工作流。

推送 `v*` tag 后，工作流构建 `.npl`、运行校验器、生成与包字节绑定的 Store schema-v2 `manifest.json`、
创建 GitHub Release，并把清单推回仓库的动态默认分支。工作流只需要 `contents: write` 权限，不需要审批 API
或任何 Secret。

发布与商店收录说明见 [插件发布与商店收录](PLUGIN_STORE_SETUP.md)。
