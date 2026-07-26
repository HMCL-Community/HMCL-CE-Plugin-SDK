# Source References

这里复制了插件开发最常用的 HMCL Nex 源码文件，方便插件作者查看接口和数据模型：

- `Plugin.java`
- `PluginContext.java`
- `PluginDependency.java`
- `PluginManifest.java`
- `PluginPermission.java`
- `PluginPermissionException.java`
- `PluginPermissionService.java`（启动器内部参考）
- `PluginVersionConstraint.java`
- `PluginContainer.java`
- `PluginStoreRegistry.java`
- `PluginStoreManifest.java`
- `PluginStoreItem.java`
- `PluginVersion.java`

这些文件由 `tools/sync-api-references.ps1` 从相邻的 HMCL Nex 仓库同步。实际编译时仍应使用启动器 JAR 作为 `compileOnly` 依赖。

`PluginPermissionService.java` 便于审查权限如何按插件 ID、版本和包 SHA-256 保存。它是包级启动器内部实现，不是插件 SDK 的可调用 API；插件只应通过 `PluginContext` 查询或要求权限，并捕获 `PluginPermissionException` 做功能降级。
