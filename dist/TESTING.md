# 示例插件测试

本目录提供面向 Aura Launcher `next` 的 schema-v5 Java、Kotlin 和 Java Mixin 基线包。每个包都声明
`runtime: "java"` 与 ABI 2。Schema v5 是语言中立合同；.NET、QuickJS/WASM、Python 和原生 provider
属于同一合同体系，但当前里程碑未提供，因此本目录不包含相应测试包。

SDK `schema-v4` 仍是稳定、默认分支，Aura Launcher `next` 也仍接受 schema-v4 包；本目录只验证本分支新生成的
schema-v5 示例。

1. 先用 `tools/validate-npl.ps1` 校验包，再在 Aura Launcher `next` 的插件管理页安装。
2. 检查授权窗口中的必要权限与可选权限。
3. 确认插件先显示为待重启，当前进程不执行新包。
4. 重启 Aura Launcher，验证 `onLoad`、`onEnable` 与页面行为。
5. 禁用或卸载插件，验证对应生命周期回调。

Mixin 示例还必须验证重启语义：安装、启用、禁用、更新和卸载都需要重启才会改变字节码注入状态。

当前里程碑的 Hook/Patch 支持仅限合同解析与验证；不要用这些包测试 Hook 分发或 Patch 执行。

运行 SDK 回归测试：

```powershell
./tools/test-validate-npl.ps1
./tools/test-publishing-tools.ps1
Get-ChildItem ./dist -Filter *.npl | ForEach-Object {
    ./tools/validate-npl.ps1 -Package $_.FullName
}
```

发布测试确认生成的 Store schema-v2 清单把 packageUrl、SHA-256 与体积精确绑定到 NPL 字节。
NPL 校验器还会核对 schema、权限、依赖、runtime、ABI 与规范化 platforms。
