# 插件快速开始

HMCL CE 接受 Java/Kotlin JVM 插件与 C# Companion 包。不要使用 JavaScript 文件作为入口，也不要在 `plugin.json` 中填写 `"type": "javascript"`。

## 复制 Java 示例

```powershell
Copy-Item -Recurse examples/java-helloworld my-hmcl-ce-plugin
$env:HMCL_JAR="../HMCL-CE/HMCL/build/libs/HMCL-CE-26.8-beta.SNAPSHOT.jar"
../HMCL-CE/gradlew.bat -p my-hmcl-ce-plugin packageNpl
```

## 配置清单

```json
{
  "schemaVersion": 4,
  "id": "com.example.hmclce.plugin",
  "name": "HMCL CE Plugin",
  "version": "1.0.0",
  "type": "java",
  "entrypoint": "com.example.hmclce.PluginMain",
  "dependencies": [],
  "permissions": ["launcher-ui"],
  "requiredPermissions": [],
  "launcherVersion": ">=26.8"
}
```

Kotlin 插件把 `type` 改为 `kotlin`，入口仍然是完整 JVM 类名。

## C# Companion 包

C# 包由独立 .NET Host 加载，根清单使用 `"type": "csharp"` 和固定入口
`"entrypoint": "companion/extension.json"`。`companion/extension.json` 的 ID 与版本必须和根清单一致。
可直接参考 `HMCL-CE-Companion/samples/HMCL.CE.Companion.RuntimeProbe`，其中的 `pack-npl.ps1` 会生成可安装包。
需要注册跨平台 C# 页面时，继续阅读 [C# 原生页面](CSHARP_NATIVE_PAGES.md)。

## 验证并安装

```powershell
./tools/validate-npl.ps1 -Package ./build/npl/com.example.hmclce.plugin-v1.0.0.npl
```

在 HMCL CE 的插件管理页安装包、确认权限并重启。首次安装和更新均不会在当前进程执行新插件。

## Mixin 插件

从 `examples/java-mixin` 开始。清单需要 `mixins`、`permissions: ["mixin"]` 与 `requiredPermissions: ["mixin"]`。启用、禁用、更新和卸载 Mixin 插件均需要重启。

## 发布

给仓库添加 Topic `hmclce`，复制 `store/manifest.template.json` 和 `store/github-release-workflow.yml`。认证发布只需要两个 Repository Variables：

推送 `v*` tag 触发工作流：构建 `.npl`、运行 `tools/validate-npl.ps1` 校验、用 `tools/sign-plugin.ps1` 生成绑定哈希与体积的 `manifest.json`，创建 GitHub Release 并把清单推回默认分支。工作流只需要 `contents: write` 权限，不需要审批 API 或任何 Secret。

发布与商店收录说明见 [插件发布与商店收录](PLUGIN_STORE_SETUP.md)。
