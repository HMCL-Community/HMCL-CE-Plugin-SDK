# HMCL CE Plugin SDK

这个 SDK 用于创建、打包、测试和发布 HMCL CE 的 JVM 插件；C# Companion 扩展由独立的 `HMCL-CE-Companion` 仓库提供。

> 重要：HMCL CE 支持 `java`、`kotlin` 和 `csharp` 包。`csharp` 包由 .NET Companion Host 执行，不能作为 JVM `Plugin` 类加载。`type: "javascript"` 已被移除；SDK 不提供 JavaScript 示例、Node.js 安装步骤、Node 打包脚本或 JavaScript UI 协议。

## 快速开始

1. 从 `examples/java-helloworld` 或 `examples/kotlin-helloworld` 复制一个工程。
2. 将 `HMCL_JAR` 指向本地 HMCL CE 构建产物。
3. 修改 `plugin.json` 的 ID、版本和入口类。
4. 构建 `.npl` 并使用 `tools/validate-npl.ps1` 校验。

```powershell
$env:HMCL_JAR="../HMCL-CE/HMCL/build/libs/HMCL-CE-26.8-beta.SNAPSHOT.jar"
../HMCL-CE/gradlew.bat -p examples/java-helloworld packageNpl
./tools/validate-npl.ps1 -Package examples/java-helloworld/build/npl/dev.hmclce.example.java.helloworld-v1.0.0.npl
```

## 支持范围

| 类型 | `plugin.json` 值 | 入口 |
| --- | --- | --- |
| Java | `java` | 实现 `Plugin` 的完整类名 |
| Kotlin | `kotlin` | 实现 `Plugin` 的完整类名 |
| C# Companion | `csharp` | 固定为 `companion/extension.json`，由 .NET Host 加载 |
| Mixin | `java` 或 `kotlin` | JVM 插件，另加 `mixins` 声明 |

所有插件都采用 schema v4。每个清单必须包含 `permissions`、`requiredPermissions` 和 `launcherVersion`。

```json
{
  "schemaVersion": 4,
  "id": "dev.example.hmclce.hello",
  "name": "HMCL CE Hello",
  "version": "1.0.0",
  "type": "java",
  "entrypoint": "dev.example.hmclce.HelloPlugin",
  "dependencies": [],
  "permissions": ["launcher-ui"],
  "requiredPermissions": [],
  "launcherVersion": ">=26.8"
}
```

## 目录

```text
examples/
├── java-helloworld/     Java 生命周期与 JavaFX 示例
├── kotlin-helloworld/   Kotlin 生命周期与 JavaFX 示例
├── java-mixin/          Java Mixin 示例
└── offline-unlocker/    Mixin 回归示例
snippets/
├── java/
└── kotlin/
tools/
├── validate-npl.ps1
├── sign-plugin.ps1          生成 schema v2 发布清单
├── publish-plugin.ps1       手工发布到 GitHub Release
└── sync-api-references.ps1
```

## 打包格式

`.npl` 是 ZIP 包，根目录包含 `plugin.json`，插件类和资源放入 `libs/*.jar`：

```text
example-plugin.npl
├── plugin.json
└── libs/example-plugin.jar
```

`entrypoint` 必须在包根目录或 `libs/*.jar` 中对应的 `.class` 资源存在。校验脚本会拒绝 JavaScript 类型和脚本入口。

C# Companion 包使用不同的负载结构：根清单保持 schema v4，`type` 为 `csharp`，`entrypoint` 固定为
`companion/extension.json`。其下的 `extension.json` 必须与根清单使用相同的 ID 和版本，DLL 和 `.deps.json`
均位于 `companion/` 目录。可参考 `HMCL-CE-Companion/samples/HMCL.CE.Companion.RuntimeProbe`。

## 生命周期与权限

插件实现 `onLoad`、`onEnable`、`onDisable` 和 `onUnload`。新安装和更新仅在重启后执行。运行期授权可能被撤销，受保护的 API 调用应使用 `context.requirePermission(...)` 并捕获 `PluginPermissionException`。

Mixin 插件必须在 `permissions` 与 `requiredPermissions` 中都声明 `mixin`，并在 `mixins` 中列出配置文件。Mixin 相关变更必须重启 HMCL CE 才会生效。

## 发布与发现

- 社区插件通过全小写 GitHub Topic `hmclce` 自动发现：默认分支根目录的 `manifest.json`（schema v2）描述版本、下载地址、SHA-256、权限与依赖，每个 Release 使用 `v<SemVer>` tag 并附上 `.npl`。
- 社区发布无需审批 API、开发者证书或人工复核；启动器在安装前校验清单、插件 ID、版本、下载地址、SHA-256、依赖与权限声明，并展示来源与权限信息。含 Mixin 的插件需要额外确认，并在重启后加载。
- 官方源 `HMCL-CE-Plugin-Store` 以 `plugins.json` 收录经社区审核的插件；被收录的插件在商店中显示已认证来源标识——这只是来源标签，不是安装前提。
- 发布模板见 `store/github-release-workflow.yml`：构建、校验、生成 `manifest.json`、创建 Release 并把清单推回默认分支，只需要 `contents: write` 权限。

完整流程见[插件发布与商店收录](docs/PLUGIN_STORE_SETUP.md)。

## 文档

- [插件快速开始](docs/PLUGIN_QUICKSTART.md)
- [插件开发指南](docs/PLUGIN_DEVELOPMENT.md)
- [C# 原生页面](docs/CSHARP_NATIVE_PAGES.md)
- [API 速查表](API_CHEATSHEET.md)
- [本地测试清单](dist/TESTING.md)
- [商店发布配置](docs/PLUGIN_STORE_SETUP.md)
