# .NET 原生页面设计边界

> 原生页面仍不可用：已发布的 Aura .NET Runtime Host 是服务于自身 payload 合同的 isolated runtime，并未实现旧
> Companion 原生页面协议。当前 .NET Host 合同应参考其
> [`examples/launch-hook`](https://github.com/Egg-China/Aura-DotNet-Runtime-Host/tree/main/examples/launch-hook)
> 源码示例。源码示例可能要求从源码构建；已发布 beta 制品不可变，可能不包含新的源码行为。

Schema v5 是语言中立的 runtime、ABI 与 platform 合同。.NET 与 QuickJS/WASM、Python、原生代码一样，
属于外部 runtime provider 的扩展方向；Java、Kotlin 和 Mixin 示例只是当前内置 `java` provider 的基线。

## 与旧 Companion 原型的关系

旧 `HMCL-CE-Companion` 原型曾使用 `CeExtensionContext.Pages`、`CePageDefinition` 和
`ICePageProvider` 描述由 JavaFX 渲染的页面，也约定过 `Sidebar`、`Settings`、`Tools` 三种位置及文本、
按钮、开关、输入和选项控件。这些类型和旧的 `companion/extension.json` 包结构不构成本分支的已支持
schema-v5 运行时合同。

即使已有发布的 isolated `dotnet` Host，原生页面和旧 Companion 协议仍未提供：

- 不要把 `type: "csharp"` 或 `companion/extension.json` 当作 Aura Launcher `next` 当前可执行入口；
- 不要基于旧 Companion 的打包脚本发布 schema-v5 NPL；
- 不要宣称 .NET 页面可以在 Windows、Linux 或 macOS 的当前启动器中运行；
- 仅可把旧页面协议作为未来 provider 设计参考。

## 未来 provider 的合同要求

未来 .NET 包必须使用 schema v5，声明规范的 runtime ID、受支持 ABI，并按需声明平台目标。只有
provider 已注册且实现请求 ABI 后，启动器才会允许包进入加载流程。当前 `next` 已具备 Provider 包的安装、
更新、卸载、自动依赖解析与生命周期监督基础；已发布的 `dotnet` Host 提供其 isolated payload 格式，
但原生页面桥接仍不可用。

Hook 与 Patch 也不会为旧 Companion 提供捷径：当前 Aura Launcher `next` 会分发已支持的游戏启动 Hook，
包括外部 Provider 端点；其他 Hook 仍是声明合同。Patch 执行还需要当前精确制品的权限授予和受支持的 Agent
instrumentation，详见
[插件开发指南](PLUGIN_DEVELOPMENT.md#patch-执行前提与回调合同).
