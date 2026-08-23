# 插件快速开始

本分支的示例生成 schema-v5 包并面向 HMCL CE `next`。Schema v5 是语言中立的 runtime、ABI 与 platform
合同；当前示例只是使用内置 `java` provider 的 Java/Kotlin/Mixin 基线。SDK `schema-v4` 仍是稳定、默认分支，
HMCL CE `next` 也仍接受 schema-v4 包。

## 复制 Java 示例

```powershell
Copy-Item -Recurse examples/java-helloworld my-hmcl-ce-plugin
$env:HMCL_JAR = (Get-ChildItem ../HMCL-CE/HMCL/build/libs/HMCL-*.jar |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
../HMCL-CE/gradlew.bat -p my-hmcl-ce-plugin clean packageNpl
```

## 配置清单

```json
{
  "schemaVersion": 5,
  "id": "com.example.hmclce.plugin",
  "name": "HMCL CE Plugin",
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

## 外部运行时边界

.NET、QuickJS/WASM、Python 与原生插件属于 schema-v5 合同，但需要各自的 runtime provider。
HMCL CE `next` 当前仅内置 `java` provider，本 SDK 当前也不提供外部 provider、外部语言模板或自动安装流程。
在 provider 实际交付前，不要把旧 C# Companion 包、JavaScript 文件或原生负载作为可执行包发布。

## 验证并安装

```powershell
./tools/validate-npl.ps1 -Package ./build/npl/com.example.hmclce.plugin-v1.0.0.npl
```

在 HMCL CE `next` 的插件管理页安装包、确认权限并重启。首次安装和更新均不会在当前进程执行新插件。

## Mixin 插件

从 `examples/java-mixin` 开始。清单需要 `mixins`、`permissions: ["mixin"]` 与
`requiredPermissions: ["mixin"]`。启用、禁用、更新和卸载 Mixin 插件均需要重启。

## Hook 与 Patch 声明

Schema v5 可以声明 Hook 与 Patch，并分别要求 `launcher-hook`、`launcher-patch` 同时列入可选和必需权限。
当前里程碑只验证这些声明，不分发 Hook，也不执行 Patch；不要依赖它们改变启动器行为。

## 发布

给仓库添加 Topic `hmclce`，复制 `store/manifest.template.json` 和 `store/github-release-workflow.yml`。
推送 `v*` tag 后，工作流构建 `.npl`、运行校验器、生成与包字节绑定的 Store schema-v2 `manifest.json`、
创建 GitHub Release，并把清单推回仓库的动态默认分支。工作流只需要 `contents: write` 权限，不需要审批 API
或任何 Secret。

发布与商店收录说明见 [插件发布与商店收录](PLUGIN_STORE_SETUP.md)。
