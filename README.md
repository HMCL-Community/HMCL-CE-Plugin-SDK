# HMCL CE Plugin SDK

这个分支提供面向 HMCL CE `next` 的 schema-v5 插件合同、校验器、Java API 快照和基线示例。
Schema v5 以 `runtime`、`abi` 与 `platforms` 描述语言和平台兼容性，是语言中立合同，并非仅供 Java 使用。

> 当前边界：HMCL CE `next` 同时接受 schema v4 和 schema v5；SDK `schema-v4` 仍是稳定、默认分支。
> `next` 当前只内置 `java` runtime provider，因此本分支的 Java、Kotlin 和 Mixin 示例都使用
> `runtime: "java"` 与 ABI 2。面向 .NET、QuickJS/WASM、Python 或原生代码的 schema-v5 包必须先有
> 对应 runtime provider；本里程碑尚未提供这些 provider，也不会自动安装它们。

## 快速开始

1. 从 `examples/java-helloworld` 或 `examples/kotlin-helloworld` 复制一个工程。
2. 将 `HMCL_JAR` 指向本地 HMCL CE `next` 构建产物。
3. 修改 `plugin.json` 的 ID、版本和入口类。
4. 构建 `.npl` 并使用 `tools/validate-npl.ps1` 校验。

```powershell
$env:HMCL_JAR = (Get-ChildItem ../../HMCL-CE/HMCL/build/libs/HMCL-*.jar |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
../../HMCL-CE/gradlew.bat -p examples/java-helloworld clean packageNpl
./tools/validate-npl.ps1 -Package examples/java-helloworld/build/npl/dev.hmclce.example.java.helloworld-v1.0.0.npl
```

## 合同与实现范围

| 层面 | schema-v5 表达 | 当前实现 |
| --- | --- | --- |
| JVM | `runtime: "java"`、ABI 2 | 内置 provider；本 SDK 提供 Java、Kotlin 与 Mixin 基线示例 |
| .NET | 独立 runtime provider | 合同预留；当前里程碑未提供 provider |
| QuickJS/WASM | 独立 JavaScript runtime provider | 合同预留；当前里程碑未提供 provider |
| Python | 独立 runtime provider | 合同预留；当前里程碑未提供 provider |
| 原生代码 | 独立 runtime provider 与平台目标 | 合同预留；当前里程碑未提供 provider |

Schema v5 保留 schema-v4 的身份、依赖、启动器版本、权限、`type`、`entrypoint` 与 Mixin 字段，并要求
显式声明规范化的 `runtime` 和受支持的 `abi`。`platforms` 可省略或设为空数组表示不限制平台；否则只能使用
规范的 `os` 或 `os-arch` 值，例如 `windows-x64`、`linux-arm64`、`macos`。

```json
{
  "schemaVersion": 5,
  "id": "dev.example.hmclce.hello",
  "name": "HMCL CE Hello",
  "version": "1.0.0",
  "type": "java",
  "runtime": "java",
  "abi": 2,
  "entrypoint": "dev.example.hmclce.HelloPlugin",
  "dependencies": [],
  "permissions": ["launcher-ui"],
  "requiredPermissions": [],
  "launcherVersion": ">=26.8"
}
```

Schema-v4 包在 `next` 上按 `runtime: "java"`、ABI 1、无平台限制处理。Schema v4 不能声明 schema-v5 的
runtime、ABI、platform、Hook 或 Patch 字段。

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

当前 JVM 基线包是 ZIP 格式，根目录包含 `plugin.json`，插件类和资源放入 `libs/*.jar`：

```text
example-plugin.npl
├── plugin.json
└── libs/example-plugin.jar
```

使用 `runtime: "java"` 时，`entrypoint` 必须对应包根目录或 `libs/*.jar` 中存在的 `.class` 资源。
外部语言包的负载结构由将来的 runtime provider 合同定义；不能把旧 C# Companion、Node.js 脚本或任意
原生负载当作当前可执行的 schema-v5 包。

## 生命周期、权限与声明能力

Java provider 加载的插件实现 `onLoad`、`onEnable`、`onDisable` 和 `onUnload`。新安装和更新仅在重启后
执行。运行期授权可能被撤销，受保护的 API 调用应使用 `context.requirePermission(...)` 并捕获
`PluginPermissionException`。

Mixin 插件必须在 `permissions` 与 `requiredPermissions` 中都声明 `mixin`，并在 `mixins` 中列出配置文件。
Mixin 相关变更必须重启 HMCL CE 才会生效。

Schema v5 还允许声明 `hooks` 和 `patches`，并分别要求 `launcher-hook`、`launcher-patch` 同时出现在
`permissions` 与 `requiredPermissions`。当前里程碑只解析、校验并暴露这些声明，不会分发 Hook，也不会执行
Patch 或字节码转换。

## 发布与发现

- 社区插件通过全小写 GitHub Topic `hmclce` 自动发现：默认分支根目录的 `manifest.json`（Store schema v2）描述版本、下载地址、SHA-256、权限、依赖以及 schema-v5 runtime/ABI/platform 合同，每个 Release 使用 `v<SemVer>` tag 并附上 `.npl`。
- 社区发布无需审批 API、开发者证书或人工复核；启动器在安装前校验清单和下载包的一致性，并展示来源与权限信息。
- 官方源 `HMCL-CE-Plugin-Store` 以 `plugins.json` 收录经社区审核的插件；被收录的插件在商店中显示已认证来源标识，这只是来源标签，不是安装前提。
- 发布模板见 `store/github-release-workflow.yml`：构建、校验、生成 `manifest.json`、创建 Release 并把清单推回仓库的动态默认分支，只需要 `contents: write` 权限。

完整流程见[插件发布与商店收录](docs/PLUGIN_STORE_SETUP.md)。

## 文档

- [插件快速开始](docs/PLUGIN_QUICKSTART.md)
- [插件开发指南](docs/PLUGIN_DEVELOPMENT.md)
- [.NET 原生页面设计边界](docs/CSHARP_NATIVE_PAGES.md)
- [API 速查表](API_CHEATSHEET.md)
- [本地测试清单](dist/TESTING.md)
- [商店发布配置](docs/PLUGIN_STORE_SETUP.md)
