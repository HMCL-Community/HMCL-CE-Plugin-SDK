# 插件开发指南

## 版本与分支

- SDK `schema-v4` 是稳定、默认分支，服务于 schema-v4 作者。
- SDK `schema-v5` 是面向 Aura Launcher `next` 的预发布分支。
- Aura Launcher `next` 同时接受 schema v4 与 schema v5；schema-v4 包映射为 `java`、ABI 1、无平台限制。

Schema v5 将清单格式与实现语言分开。`runtime` 选择运行时提供者，`abi` 选择插件 ABI 代际，`platforms`
限制可运行主机。因此 schema v5 是多语言、语言中立合同；本仓库中的 Java、Kotlin 和 Mixin 仅是当前可执行的
JVM 基线。

## 运行时状态

| 运行时方向 | schema-v5 归属 | 当前可用性 |
| --- | --- | --- |
| Java/Kotlin/Mixin | 内置 `java` provider | 可用；示例使用 ABI 2 |
| Rust | 可选 Rust Host provider | [已独立发布](https://github.com/Egg-China/Aura-Rust-Runtime-Host) |
| .NET | 可选 .NET Host provider | [已独立发布](https://github.com/Egg-China/Aura-DotNet-Runtime-Host) |
| QuickJS | 可选 JavaScript Host provider | [已独立发布](https://github.com/Egg-China/Aura-QuickJS-Runtime-Host) |
| Wasm | 可选 Wasm Host provider | [已独立发布](https://github.com/Egg-China/Aura-Wasm-Runtime-Host) |
| Python | 外部 provider | 尚未发布 Host |
| 原生代码 | 外部 provider，并通常声明平台 | 本里程碑未提供 |

Aura Launcher `next` 已实现可选 Runtime Provider 的声明、Store 依赖解析、安装绑定、生命周期监督、语言中立 Bridge
与权限令牌基础。没有已安装且支持目标 ABI、执行模式和派生功能的 provider 时，启动器会在加载负载前拒绝包。
Rust、.NET、QuickJS 与 Wasm Host 是单独安装和更新的可选插件；Python 仍没有已发布 Host。四个 Host 当前的
源码示例都位于各自仓库的 `examples/launch-hook`：[Rust](https://github.com/Egg-China/Aura-Rust-Runtime-Host/tree/main/examples/launch-hook)、
[.NET](https://github.com/Egg-China/Aura-DotNet-Runtime-Host/tree/main/examples/launch-hook),
[QuickJS](https://github.com/Egg-China/Aura-QuickJS-Runtime-Host/tree/main/examples/launch-hook) 和
[Wasm](https://github.com/Egg-China/Aura-Wasm-Runtime-Host/tree/main/examples/launch-hook)。示例所需的当前 Host
提交未包含在已发布 beta 中时，应构建源码；已发布 beta 制品保持不可变。

## JVM 包结构

```text
plugin.npl
├── plugin.json
└── libs/
    └── plugin.jar
```

使用 `runtime: "java"` 时，`entrypoint` 对应的 `.class` 必须在包根目录或一个 `libs/*.jar` 中。其他 runtime
把 `entrypoint` 解释为包内规范、安全、不可逃逸的相对路径；选中的 Provider 再校验该负载是否符合其格式和平台。
本 SDK 不打包外部 payload 模板；应使用 Host 仓库中的 `examples/launch-hook` 源码。

## 清单

```json
{
  "schemaVersion": 5,
  "id": "com.example.hmclce.plugin",
  "name": "Aura Plugin",
  "version": "1.0.0",
  "type": "java",
  "runtime": "java",
  "abi": 2,
  "platforms": [],
  "entrypoint": "com.example.hmclce.PluginMain",
  "dependencies": [],
  "permissions": ["launcher-ui"],
  "requiredPermissions": [],
  "launcherVersion": ">=26.8"
}
```

`runtime` 必须是规范的小写标识。ABI 必须受当前合同支持。`platforms` 省略或为空表示不限平台；非空数组的
每个值必须是规范、唯一的 `os` 或 `os-arch` 标识。`harmonyos-arm64` 是独立实验性目标；在 HarmonyOS
PC ARM64 上可单向匹配 `linux-arm64`，反向匹配与其他 HarmonyOS 架构均不允许。`permissions` 是完整声明，`requiredPermissions` 必须是
其中的子集。启动器实际授予的能力绑定插件 ID、版本和包 SHA-256；更新包需要重新确认授权。

普通语言插件可用 `executionMode: "embedded"` 或 `"isolated"` 选择执行边界，并可用规范的
`runtimeProvider` 插件 ID 固定 Provider。未声明模式时默认为 `embedded`。隔离负载不能请求 `jvm-raw`。

Runtime Provider 本身是 `runtime: "java"`、`pluginKind: "runtime-provider"`、嵌入执行的 Java 启动插件。
`providesRuntimes` 中每个不重复的 runtime 声明正整数 ABI 集、正整数 Bridge ABI、非空执行模式集与功能集；
功能值限于 `bridge`、`hooks`、`patches`、`raw-jvm`、`native`，并且必须包含 `bridge`。声明 `native` 或
`raw-jvm` 的 Provider 还必须声明 `native-code` 权限。Provider 不能覆盖内置 `java`，也不能固定另一个 Provider。

## 生命周期

```java
public final class PluginMain implements Plugin {
    private PluginContext context;

    @Override
    public void onLoad(PluginContext context) {
        this.context = context;
    }

    @Override
    public void onEnable() {
        if (context.isPermissionGranted(PluginPermission.LAUNCHER_UI)) {
            context.registerSidebarItem("Plugin", () -> Controllers.dialog("Enabled", "Plugin"));
        }
    }
}
```

不要只在 `onLoad` 缓存授权状态。用户可以在运行期撤销权限，调用受保护 API 时应检查权限并捕获
`PluginPermissionException`。

## Mixin

当前 Mixin 基线由 `java` provider 执行。把配置文件放入插件 JAR，声明 `mixins`，并把 `mixin` 同时放入
`permissions` 和 `requiredPermissions`。Mixin 变更需要重启，因为启动器会在类加载前由 Agent 完成验证与注入。

## Hook 与 Patch

Schema v5 的 `hooks` 与 `patches` 是声明式合同：

- Hook 声明要求 `launcher-hook` 同时位于 `permissions` 和 `requiredPermissions`。
- Patch 声明要求 `launcher-patch` 同时位于两个权限列表。
- Patch 使用目标类、方法名、`before`/`after`/`replace` 类型以及有序参数列表定位重载。

Aura Launcher `next` 已接入游戏启动前后的 Hook 分发；其余 Hook 仍是声明合同。

## Patch 执行前提与回调合同

修改声明前，应先构建并校验 [Java Patch 示例](../examples/java-patch/README.md)。在 SDK 根目录运行以下命令：

```powershell
$sdkRoot = (Resolve-Path '.').Path
$exampleProject = Join-Path $sdkRoot 'examples\java-patch'
$env:HMCL_JAR = 'path-to-Aura-Launcher-27.1-next.jar'
$gradle = if ($env:AURA_GRADLE) { (Resolve-Path $env:AURA_GRADLE).Path } else { (Get-Command gradle -ErrorAction Stop).Source }
& $gradle -p $exampleProject test packageNpl --no-daemon --console=plain
& (Join-Path $sdkRoot 'tools\validate-npl.ps1') -Package (Join-Path $exampleProject 'build\npl\dev.hmclce.example.java.patch-v1.0.0.npl')
```

安装该精确包、授予其当前精确制品的 `launcher-patch` 权限，并重启启动器。普通 27.1 Patch 制品可以没有认证收据；
任何提供的收据都会被验证，并可能被撤销。不要将后续 UI provider 的强制官方/认证收据规则应用于普通 Patch 插件。

当前自动 bootstrap 重启仅适用于已启用的 Mixin 配置。仅声明 Patch 不会启动 instrumentation。为确定性的本地执行，
同一 Aura 打包 JAR 应同时按两种方式调用：

```powershell
$auraJar = (Resolve-Path $env:HMCL_JAR).Path
java "-javaagent:$auraJar" -jar $auraJar
```

只有安装了受支持的 instrumentation，注册才会生效；否则返回 `PATCH_ENGINE_UNAVAILABLE`。注册和回调会重新检查
生命周期和权限授权，撤销权限或关闭端点会使注册失效。这是授权和生命周期约束，不是 JVM 内安全沙箱。

`before` 可以返回不变结果或替换参数。`after` 可以返回不变结果或替换返回值；`void` 方法的结果为 `null`，且只允许
不变结果。`replace` 可以返回不变结果或替换返回值。声明用目标类、方法、有序参数类型和上述类型之一定位。`before`
回调按依赖优先运行；`after` 回调按反向依赖顺序运行；其他情况以插件 ID 进行确定性排序。冲突的 `replace` 注册会被拒绝。

默认期限为每个回调 500 ms、一次聚合调用 2 s。回调异常、传输或 wire 失败、超时、生命周期失败或权限拒绝均会
fail-open：引擎保留原始或当前调用，不会应用部分插件结果。

外部 Provider 使用 `aura.patch.v1` 和 Bridge Value v1，而非普通 JSON。请求是有序 Map，字段依次为
`schemaVersion`、`target`、`method`、`parameters`、`type`、`receiver`、`arguments`、`result`；不变响应严格按
`schemaVersion: integer 1`、`action: "unchanged"` 排列。QuickJS 必须使用有序 `Map` 和 `1n`，不能使用 JSON
对象或数字。receiver 和对象值是调用局部 handle：响应解码或调用关闭时会过期，不能保留，也不是可序列化的 JVM token。

## 校验与发布

```powershell
./tools/validate-npl.ps1 -Package ./build/npl/plugin.npl
Get-FileHash ./build/npl/plugin.npl -Algorithm SHA256
```

本分支校验器接受 schema v4 和 v5，因为 Aura Launcher `next` 同时支持两者。发布 schema-v5 包时，Store
`versions[]` 条目必须使用 `pluginApiVersion: 5`，并让 runtime、ABI、规范化 platforms、Provider 字段、权限与
依赖精确匹配包内 `plugin.json`。Runtime Provider 的 Store 版本必须使用 `artifacts` 矩阵；每个 artifact 使用唯一、
包含架构的精确平台目标，并独立声明 `packageUrl`、小写 SHA-256 与正整数 `size`。矩阵不能与版本级
`packageUrl`、`sha256` 或 `size` 混用。

用户启用 Topic 发现后，第三方仓库可使用全小写 GitHub Topic `aura-launcher`，并在默认分支发布 Store schema-v2
`manifest.json`。工作流只需要 `contents: write` 权限，不需要开发者签名私钥、长期 API Key、审批 API 或 Secret。
官方源收录 PR 修改 `registry.json`（schema-v1 源数据）；生成的已签名 `plugins.json` 不可手工编辑，收录只增加来源标识。

.NET 原生页面的历史设计边界见 [.NET 原生页面设计边界](CSHARP_NATIVE_PAGES.md)；它不是当前可执行能力。
