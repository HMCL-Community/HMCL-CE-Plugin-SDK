# Source References

这里复制了插件开发最常用的 HMCL Nex 源码文件，方便插件作者查看接口和数据模型：

- `Plugin.java`
- `PluginContext.java`
- `PluginManifest.java`
- `PluginContainer.java`
- `PluginStoreRegistry.java`
- `PluginStoreManifest.java`
- `PluginStoreItem.java`
- `PluginVersion.java`

这些文件由 `tools/sync-api-references.ps1` 从相邻的 HMCL Nex 仓库同步。实际编译时仍应使用启动器 JAR 作为 `compileOnly` 依赖。
