# Aura Launcher Plugin SDK

这个分支提供面向 Aura Launcher `next` 的 schema-v5 插件合同、校验器、Java API 快照和基线示例。
Schema v5 以 `runtime`、`abi` 与 `platforms` 描述语言和平台兼容性，是语言中立合同，并非仅供 Java 使用。

> 当前边界：Aura Launcher `next` 同时接受 schema v4 和 schema v5；SDK `schema-v4` 仍是稳定、默认分支。
> `next` 当前只内置 `java` runtime provider，因此本分支的 Java、Kotlin、Mixin 和 Patch 示例都使用
> `runtime: "java"` 与 ABI 2。Rust、.NET、QuickJS 与 Wasm payload 使用各自独立发布的可选 Runtime Host；
> Python 或其他原生代码仍需对应的 runtime provider，启动器不会自动安装任何外部 Host。
>
> 源代码示例跟随当前 Host 源码。已发布的 beta 制品是不可变的历史版本：需要时应从源码构建，并在安装 Host
> 和 payload 前核对其 ABI。

## 快速开始

1. 从 `examples/java-helloworld` 或 `examples/kotlin-helloworld` 复制一个工程。
2. 将 `AURA_LAUNCHER_SOURCE` 指向本地 Aura Launcher 源码目录；兼容变量 `HMCL_JAR` 指向其 `next` JAR。
3. 修改 `plugin.json` 的 ID、版本和入口类。
4. 构建 `.npl` 并使用 `tools/validate-npl.ps1` 校验。

```powershell
$aura = Resolve-Path $env:AURA_LAUNCHER_SOURCE
$env:HMCL_JAR = (Get-ChildItem "$aura/AuraLauncher/build/libs/Aura-Launcher-*.jar" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
& "$aura/gradlew.bat" -p examples/java-helloworld clean packageNpl
./tools/validate-npl.ps1 -Package examples/java-helloworld/build/npl/dev.hmclce.example.java.helloworld-v1.0.0.npl
```

## 合同与实现范围

| 层面 | schema-v5 表达 | 当前实现 |
| --- | --- | --- |
| JVM | `runtime: "java"`、ABI 2 | 内置 provider；本 SDK 提供 Java、Kotlin 与 Mixin 基线示例 |
| Rust | `runtime: "rust"`、ABI 1 | 可选 [Aura Rust Runtime Host](https://github.com/Egg-China/Aura-Rust-Runtime-Host) |
| .NET | `runtime: "dotnet"`、ABI 1 | 可选 [Aura .NET Runtime Host](https://github.com/Egg-China/Aura-DotNet-Runtime-Host) |
| QuickJS | `runtime: "javascript"`、ABI 1 | 可选 [Aura QuickJS Runtime Host](https://github.com/Egg-China/Aura-QuickJS-Runtime-Host) |
| Wasm | `runtime: "wasm"`、ABI 1 | 可选 [Aura Wasm Runtime Host](https://github.com/Egg-China/Aura-Wasm-Runtime-Host) |
| Python | 独立 runtime provider | 尚未发布 Host |
| 原生代码 | 独立 runtime provider 与平台目标 | 合同预留；当前里程碑未提供 provider |

Schema v5 保留 schema-v4 的身份、依赖、启动器版本、权限、`type`、`entrypoint` 与 Mixin 字段，并要求
显式声明规范化的 `runtime` 和受支持的 `abi`。`platforms` 可省略或设为空数组表示不限制平台；否则只能使用
规范的 `os` 或 `os-arch` 值，例如 `windows-x64`、`linux-arm64`、`macos`、`harmonyos-arm64`。

`harmonyos` 是独立操作系统标识。Aura Launcher 在 HarmonyOS PC ARM64 上优先选择 `harmonyos-arm64`
制品；没有该制品时可单向回退到 `linux-arm64`。HarmonyOS PC 使用 Linux 内核，因此 Linux ARM64
制品原则上可能运行，但 Aura Launcher、JavaFX、Minecraft 与现有 Runtime Host 尚未在真机验证。
HarmonyOS 的其他架构不在当前支持范围内，HarmonyOS 制品也不会反向匹配 Linux。

```json
{
  "schemaVersion": 5,
  "id": "dev.example.hmclce.hello",
  "name": "Aura Hello",
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
├── java-launch-hook/    Java 游戏启动 Hook 示例
├── java-patch/          Java Patch 回调示例
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
Java Patch 示例见 [examples/java-patch](examples/java-patch/README.md)。外部 Runtime Host 的可运行源码示例
均在各自仓库的 `examples/launch-hook`：[Rust](https://github.com/Egg-China/Aura-Rust-Runtime-Host/tree/main/examples/launch-hook)、
[.NET](https://github.com/Egg-China/Aura-DotNet-Runtime-Host/tree/main/examples/launch-hook)、
[QuickJS](https://github.com/Egg-China/Aura-QuickJS-Runtime-Host/tree/main/examples/launch-hook) 和
[Wasm](https://github.com/Egg-China/Aura-Wasm-Runtime-Host/tree/main/examples/launch-hook)。其他外部语言包的负载结构由对应 runtime
provider 合同定义；不能把旧 C# Companion、Node.js 脚本或任意原生负载当作当前可执行的 schema-v5 包。

## 生命周期、权限与声明能力

Java provider 加载的插件实现 `onLoad`、`onEnable`、`onDisable` 和 `onUnload`。新安装和更新仅在重启后
执行。运行期授权可能被撤销，受保护的 API 调用应使用 `context.requirePermission(...)` 并捕获
`PluginPermissionException`。

Mixin 插件必须在 `permissions` 与 `requiredPermissions` 中都声明 `mixin`，并在 `mixins` 中列出配置文件。
Mixin 相关变更必须重启 Aura Launcher 才会生效。

Schema v5 还允许声明 `hooks` 和 `patches`，并分别要求 `launcher-hook`、`launcher-patch` 同时出现在
`permissions` 与 `requiredPermissions`。当前 `next` 会分发已支持的游戏启动 Hook；其他 Hook 仍是声明合同。
Patch 的编写、Agent 启动、排序和失败行为见
[插件开发指南](docs/PLUGIN_DEVELOPMENT.md#patch-执行前提与回调合同)；仅声明 Patch 不会启动 JVM Agent。

## 发布与发现

- 用户启用 GitHub Topic 发现后，社区插件可通过全小写 Topic `aura-launcher` 被发现：默认分支根目录的 `manifest.json`（Store schema v2）描述版本、下载地址、SHA-256、权限、依赖以及 schema-v5 runtime/ABI/platform 合同，每个 Release 使用 `v<SemVer>` tag 并附上 `.npl`。
- 社区发布无需审批 API、开发者证书或人工复核；启动器在安装前校验清单和下载包的一致性，并展示来源与权限信息。
- 官方源 [Aura-Launcher-Plugin-Store](https://github.com/Egg-China/Aura-Launcher-Plugin-Store) 的收录 PR 修改 `registry.json`（schema-v1 源数据）；`plugins.json` 是生成的已签名信封，不能手工编辑。被收录的插件在商店中显示已认证来源标识，这只是来源标签，不是安装前提。
- 发布模板见 `store/github-release-workflow.yml`：构建、校验、生成 `manifest.json`、创建 Release 并把清单推回仓库的动态默认分支，只需要 `contents: write` 权限。

完整流程见[插件发布与商店收录](docs/PLUGIN_STORE_SETUP.md)。

## 文档

- [插件快速开始](docs/PLUGIN_QUICKSTART.md)
- [插件开发指南](docs/PLUGIN_DEVELOPMENT.md)
- [.NET 原生页面设计边界](docs/CSHARP_NATIVE_PAGES.md)
- [API 速查表](API_CHEATSHEET.md)
- [本地测试清单](dist/TESTING.md)
- [商店发布配置](docs/PLUGIN_STORE_SETUP.md)
