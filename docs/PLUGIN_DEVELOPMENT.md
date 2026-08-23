# 插件开发指南

## 版本与分支

- SDK `schema-v4` 是稳定、默认分支，服务于 schema-v4 作者。
- SDK `schema-v5` 是面向 HMCL CE `next` 的预发布分支。
- HMCL CE `next` 同时接受 schema v4 与 schema v5；schema-v4 包映射为 `java`、ABI 1、无平台限制。

Schema v5 将清单格式与实现语言分开。`runtime` 选择运行时提供者，`abi` 选择插件 ABI 代际，`platforms`
限制可运行主机。因此 schema v5 是多语言、语言中立合同；本仓库中的 Java、Kotlin 和 Mixin 仅是当前可执行的
JVM 基线。

## 运行时状态

| 运行时方向 | schema-v5 归属 | 当前可用性 |
| --- | --- | --- |
| Java/Kotlin/Mixin | 内置 `java` provider | 可用；示例使用 ABI 2 |
| .NET | 外部 provider | 本里程碑未提供 |
| QuickJS/WASM | 外部 JavaScript provider | 本里程碑未提供 |
| Python | 外部 provider | 本里程碑未提供 |
| 原生代码 | 外部 provider，并通常声明平台 | 本里程碑未提供 |

没有已注册且支持目标 ABI 的 provider 时，启动器会在加载插件代码前拒绝包。当前里程碑不负责 provider 生命周期、
自动安装或外部语言负载执行。

## JVM 包结构

```text
plugin.npl
├── plugin.json
└── libs/
    └── plugin.jar
```

使用 `runtime: "java"` 时，`entrypoint` 对应的 `.class` 必须在包根目录或一个 `libs/*.jar` 中。
其他 runtime 的负载结构必须由未来 provider 合同定义；当前 SDK 没有可发布的 .NET、QuickJS/WASM、Python
或原生包模板。

## 清单

```json
{
  "schemaVersion": 5,
  "id": "com.example.hmclce.plugin",
  "name": "HMCL CE Plugin",
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
每个值必须是规范、唯一的 `os` 或 `os-arch` 标识。`permissions` 是完整声明，`requiredPermissions` 必须是
其中的子集。启动器实际授予的能力绑定插件 ID、版本和包 SHA-256；更新包需要重新确认授权。

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

本里程碑只解析、校验并通过 API 暴露声明。HMCL CE `next` 尚未接入 Hook 分发，也没有 Patch 字节码执行引擎。

## 校验与发布

```powershell
./tools/validate-npl.ps1 -Package ./build/npl/plugin.npl
Get-FileHash ./build/npl/plugin.npl -Algorithm SHA256
```

本分支校验器接受 schema v4 和 v5，因为 HMCL CE `next` 同时支持两者。发布 schema-v5 包时，Store
`versions[]` 条目必须使用 `pluginApiVersion: 5`，并让 runtime、ABI、规范化 platforms、权限与依赖精确匹配
包内 `plugin.json`。

第三方仓库使用全小写 GitHub Topic `hmclce`，默认分支发布 Store schema-v2 `manifest.json`。工作流只需要
`contents: write` 权限，不需要开发者签名私钥、长期 API Key、审批 API 或 Secret。官方源收录只增加来源标识。

.NET 原生页面的历史设计边界见 [.NET 原生页面设计边界](CSHARP_NATIVE_PAGES.md)；它不是当前可执行能力。
