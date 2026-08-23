# 更新日志

本文档记录 HMCL CE Plugin SDK 的主要变更。

## 未发布

- 社区插件改为通过 GitHub Topic `hmclce` 自动发现，默认分支发布 schema v2 `manifest.json`。
- 官方认证改为仓库与 NPL 双验证：仓库每七天复核，每个新包均由审批服务独立下载、校验并签发制品证明。
- 新增 GitHub Actions OIDC 审批客户端；客户端按不可变仓库验证 ID 等待复核，并将该 ID 显式绑定到 NPL 审批。认证发布不再使用开发者私钥、长期 API Key 或 `HMCLCE_PLUGIN_CERTIFICATE`。
- 发布模板支持 `community`/`certified` 双模式；认证模式先创建草稿 Release，审批成功后再发布 NPL、证明与默认分支清单。
- 发布模板中的第三方 GitHub Action 固定到完整 commit SHA，禁止使用可移动的主版本标签或分支。
- HMCL CE 通过签名在线状态快照获得仓库、NPL 和在线签名 key ID 吊销状态，并实施过期与防回滚检查。
- 官方索引条目新增 `manifestSha256`，防止签名索引引用的远程清单被原地替换。

- HMCL CE 插件系统现支持 Java/Kotlin JVM 插件与 C# Companion 扩展。
- 移除了 JavaScript 插件、Node.js 运行时下载、JavaScript UI 协议、示例和打包脚本。
- 支持 schema v4 插件清单、必要/可选权限和启动器版本约束。
- 补充插件依赖版本约束、重启事务与插件商店注册模板。
- 补齐 `PluginDependency`、`PluginPermission`、
  `PluginPermissionException`、`PluginPermissionService` 和
  `PluginVersionConstraint` API 参考。
- 新增 Offline Account Unlocker 真实 Mixin 示例及隔离的 RED/GREEN 回归脚本。
- 补充插件商店、发布工作流和包验证文档。

## 插件 API v2

- 更新 Java、Kotlin、JavaScript 和 Mixin 示例以匹配第二版插件 API。
- 增补插件生命周期、JavaScript UI 协议和商店发布指南。

对应提交：`814b844`、`e476c65`。

## 初始版本

- 初始化插件 SDK 的首个版本。
- 添加基础插件示例、打包工具与开发文档。
- 完善 JavaScript UI 协议。

对应提交：`94b8b95`、`5a9ef45`。
