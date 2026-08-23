# 更新日志

本文档记录 HMCL CE Plugin SDK 的主要变更。

## 未发布

- 新增面向 HMCL CE `next` 的 schema-v5 预发布合同，以 `runtime`、`abi` 与 `platforms` 提供语言中立的兼容性描述。
- 保持 SDK `schema-v4` 为稳定、默认分支；HMCL CE `next` 同时接受 schema-v4 与 schema-v5 包。
- 将 Java、Kotlin、Java Mixin 与 Offline Account Unlocker 示例迁移到 schema 5、内置 `java` runtime 与 ABI 2。
- 扩展 NPL 校验器，覆盖 schema v4/v5、runtime、ABI、platform、Hook、Patch、权限耦合以及 Store/NPL 元数据一致性。
- 同步 HMCL CE `next` 的 Java API 快照与 Store API 快照。
- .NET、QuickJS/WASM、Python 与原生 provider 属于 schema-v5 体系，但当前里程碑尚未提供；外部 runtime 包在 provider 可用前不能执行。
- Hook 与 Patch 当前只完成合同解析、校验和 API 暴露，尚未实现 Hook 分发或 Patch 执行。
- 社区插件发布改为全小写 GitHub Topic `hmclce` 自动发现：默认分支 `manifest.json`（schema v2）加 Release `v<SemVer>` 附 `.npl` 即可上架，无需审批 API。
- 移除审批 API 客户端（request-certification.ps1）、`id-token: write`、`HMCLCE_APPROVAL_API_URL` 与 certified/community 双模式发布模板。
- 官方源收录改为在 `HMCL-CE-Plugin-Store` 仓库 `plugins.json` 中登记（含 `manifestUrl` 与 `manifestSha256`）；收录仅提供商店内的已认证来源标识。
- 发布模板改为单一社区工作流：构建、校验、生成 `manifest.json`、创建 Release 并回写默认分支清单。
- 移除旧 JavaScript 插件、Node.js 运行时下载、JavaScript UI 协议、示例与打包脚本。
- 支持 schema v4 插件清单、必需/可选权限与启动器版本约束。
- 补充插件依赖版本约束、重启事务与插件商店注册模板。
- 补齐 `PluginDependency`、`PluginPermission`、`PluginPermissionException`、`PluginPermissionService` 与 `PluginVersionConstraint` API 参考。
- 新增 Offline Account Unlocker 真实 Mixin 示例及隔离的 RED/GREEN 回归脚本。
- 补充插件商店、发布工作流与包校验文档。

## 插件 API v2

- 更新 Java、Kotlin、JavaScript 和 Mixin 示例以匹配第二版插件 API。
- 增补插件生命周期、JavaScript UI 协议和商店发布指南。

对应提交：`814b844`、`e476c65`。

## 初始版本

- 初始化插件 SDK 的首个版本。
- 添加基础插件示例、打包工具与开发文档。
- 完善 JavaScript UI 协议。

对应提交：`94b8b95`、`5a9ef45`。
