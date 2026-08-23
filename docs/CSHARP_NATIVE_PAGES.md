# C# 原生页面

C# Companion 扩展通过 `CeExtensionContext.Pages` 注册页面。页面状态和动作由 .NET 10 扩展处理，HMCL CE 使用 JavaFX 原生控件渲染，因此同一插件页面可在 Windows、Linux 和 macOS 使用。

## 开始开发

1. 以 `D:\HMCL-CE-Companion\samples\HMCL.CE.Companion.RuntimeProbe` 为工程模板。
2. 在扩展的 `OnLoadAsync` 中注册 `CePageDefinition` 和 `ICePageProvider`。
3. 从 `RenderAsync` 返回完整 `CePageDocument`。
4. 在 `InvokeAsync` 中处理动作并返回更新后的完整文档。
5. 使用示例的 `pack-npl.ps1` 打包，再用本 SDK 的 `tools/validate-npl.ps1` 校验。

```csharp
public ValueTask OnLoadAsync(CeExtensionContext context)
{
    context.Pages.Register(
        new CePageDefinition(
            $"{context.ExtensionId}.settings",
            "插件设置",
            "由 C# 提供的跨平台页面",
            CePagePlacement.Settings),
        pageProvider);
    return ValueTask.CompletedTask;
}
```

## 页面能力

| 控件 | C# 类型 | 动作值 |
| --- | --- | --- |
| 文本 | `CePageText` | 无 |
| 键值 | `CePageKeyValue` | 无 |
| 按钮 | `CePageButton` | JSON `null` |
| 开关 | `CePageToggle` | JSON Boolean |
| 单行输入 | `CePageInput` | JSON string |
| 单选菜单 | `CePageChoice` | 选项的 JSON string 值 |

页面可放在 `Sidebar`、`Settings` 或 `Tools`。每次动作响应都必须返回完整替换文档，不要只返回发生变化的控件。

完整可编译示例、动作处理、JVM Hook 调用和限制见 `D:\HMCL-CE-Companion\docs\native-pages.md`。

## Avalonia 范围

当前 `HMCL.CE.Companion.Avalonia` 是独立桌面壳工程。扩展上下文尚未提供打开 Avalonia 窗口的服务，也不能把 Avalonia 控件嵌入 JavaFX 页面。可安装插件界面应使用上述原生页面协议。
