# 示例插件测试

本目录提供 Java、Kotlin 和 Java Mixin 示例插件的发布包。

1. 在 HMCL CE 的插件管理页安装一个 `.npl`。
2. 检查授权窗口中的必要权限与可选权限。
3. 确认插件先显示为待重启，当前进程不执行新包。
4. 重启 HMCL CE，验证 `onLoad`、`onEnable` 与页面行为。
5. 禁用或卸载插件，验证对应生命周期回调。

Mixin 示例还必须验证重启语义：安装、启用、禁用、更新和卸载都需要重启才会改变字节码注入状态。

JavaScript 插件和 Node.js 运行时不在 HMCL CE 的支持范围内，测试包中不应包含它们。

发布工具和审批 API 客户端的本地回归测试：

```powershell
./tools/test-publishing-tools.ps1
./tools/test-request-certification.ps1
```

前一个测试确认未认证清单精确绑定 NPL 字节，并拒绝旧开发者密钥和手工认证发布。后一个测试使用本地 HTTP fixture 验证 GitHub OIDC Bearer、异步审批轮询、逐版本证明写入和摘要错配拒绝。
