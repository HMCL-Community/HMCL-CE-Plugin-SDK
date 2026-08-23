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
├── sign-plugin.ps1          生成未认证清单
├── request-certification.ps1 通过 GitHub OIDC 请求认证
├── publish-plugin.ps1       仅用于社区模式手工发布
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

## 当前发布要求

- GitHub 仓库必须添加全小写 Topic `hmclce`，默认分支根目录必须提供 `manifest.json`。
- 新包必须使用 `plugin.json` schema v4；商店清单必须使用 schema v2。
- tag 使用 `v<SemVer>`，Release 中同时发布 `.npl` 和本次生成的 `manifest.json`。
- 社区模式发布未认证清单；认证模式必须同时通过仓库复核和当前版本 `.npl` 独立审核。
- 仓库认证最多保留七天；每个新 `.npl` 都会由审批服务重新下载、校验摘要与包内容并签发 `artifactAttestation`。
- 认证工作流必须授予 `id-token: write`，并配置 Repository Variable `HMCLCE_APPROVAL_API_URL`。审批使用 GitHub OIDC，不需要开发者私钥、长期 API Key 或认证证书 Secret。
- 认证 Release 会先保持草稿状态；工作流先按不可变 `verificationId` 等待仓库复核，再用该 ID 提交 NPL。只有审批服务返回与仓库、tag、提交、资产 ID、插件 ID、版本、SHA-256 和字节数完全一致的证明后才发布。
- HMCL CE 会从根元数据固定的地址更新签名状态快照。仓库或具体 NPL 被吊销后，认证标签失效；已安装且明确吊销的包会在加载前被隔离。
- 声明了认证但证明缺失、签名错误、字段不匹配、状态过期或已吊销时会被拒绝，不能回退为社区来源。

完整工作流、审批 API 和字段要求见[商店发布配置](docs/PLUGIN_STORE_SETUP.md)。

## 文档

- [插件快速开始](docs/PLUGIN_QUICKSTART.md)
- [插件开发指南](docs/PLUGIN_DEVELOPMENT.md)
- [C# 原生页面](docs/CSHARP_NATIVE_PAGES.md)
- [API 速查表](API_CHEATSHEET.md)
- [本地测试清单](dist/TESTING.md)
- [商店发布配置](docs/PLUGIN_STORE_SETUP.md)
