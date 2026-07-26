# 更新日志

本文档记录 HMCL Nex Plugin SDK 的主要变更。

## 未发布

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

- 初始化 HMCL Nex 插件 SDK。
- 添加基础插件示例、打包工具与开发文档。
- 完善 JavaScript UI 协议。

对应提交：`94b8b95`、`5a9ef45`。
