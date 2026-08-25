# .NET 原生页面设计边界

> 当前不可执行：HMCL CE `next` 的 schema-v5 合同允许未来通过 `dotnet` runtime provider 承载 .NET
> 插件，但本里程碑未提供或安装该 provider。当前 SDK 也没有可发布的 .NET 模板、负载格式或页面桥接实现。

Schema v5 是语言中立的 runtime、ABI 与 platform 合同。.NET 与 QuickJS/WASM、Python、原生代码一样，
属于外部 runtime provider 的扩展方向；Java、Kotlin 和 Mixin 示例只是当前内置 `java` provider 的基线。

## 与旧 Companion 原型的关系

旧 `HMCL-CE-Companion` 原型曾使用 `CeExtensionContext.Pages`、`CePageDefinition` 和
`ICePageProvider` 描述由 JavaFX 渲染的页面，也约定过 `Sidebar`、`Settings`、`Tools` 三种位置及文本、
按钮、开关、输入和选项控件。这些类型和旧的 `companion/extension.json` 包结构不构成本分支的已支持
schema-v5 运行时合同。

在正式 `dotnet` provider、具体负载格式与页面桥接完成并发布前：

- 不要把 `type: "csharp"` 或 `companion/extension.json` 当作 HMCL CE `next` 当前可执行入口；
- 不要基于旧 Companion 的打包脚本发布 schema-v5 NPL；
- 不要宣称 .NET 页面可以在 Windows、Linux 或 macOS 的当前启动器中运行；
- 仅可把旧页面协议作为未来 provider 设计参考。

## 未来 provider 的合同要求

未来 .NET 包必须使用 schema v5，声明规范的 runtime ID、受支持 ABI，并按需声明平台目标。只有
provider 已注册且实现请求 ABI 后，启动器才会允许包进入加载流程。当前 `next` 已具备 Provider 包的安装、
更新、卸载、自动依赖解析与生命周期监督基础；尚未提供的是具体 `dotnet` Host、负载格式和页面桥接。

Hook 与 Patch 也不会为旧 Companion 提供捷径：当前 HMCL CE `next` 会分发已支持的游戏启动 Hook，
包括外部 Provider 端点；其他 Hook 仍是声明合同，Patch 字节码执行引擎尚未提供。
