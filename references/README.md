# Source References

这里复制了插件开发最常用的 HMCL CE 源码文件，方便插件作者查看接口和数据模型：

- `Plugin.java`
- `PluginCapabilityLevel.java`
- `PluginContext.java`
- `PluginDataObject.java`
- `PluginDataValue.java`
- `PluginDependency.java`
- `PluginHookEvent.java`
- `PluginHookPoint.java`
- `PluginHookResult.java`
- `PluginManifest.java`
- `PluginPatchDeclaration.java`
- `PluginPermission.java`
- `PluginPermissionException.java`
- `PluginPermissionService.java`（启动器内部参考）
- `PluginPermissionTier.java`
- `PluginSecretAccess.java`
- `PluginVersionConstraint.java`
- `PluginContainer.java`
- `JavaRuntimeProvider.java`
- `PluginAbi.java`
- `PluginCompatibilityRequirements.java`
- `PluginPlatformTarget.java`
- `PluginRuntimeTypes.java`
- `RuntimeProvider.java`
- `RuntimeProviderRegistry.java`
- `PluginStoreRegistry.java`
- `PluginStoreManifest.java`
- `PluginStoreItem.java`
- `PluginVersion.java`

这些文件由 `tools/sync-api-references.ps1` 从相邻的 HMCL CE 仓库同步。实际编译时仍应使用启动器 JAR 作为 `compileOnly` 依赖。

Schema v5 以 `runtime`、`abi` 与 `platforms` 定义语言无关的执行契约；这里的 Java 类型是 HMCL CE `next` 当前公开契约的源码快照，并不把 schema v5 限定为 Java 插件格式。`before-game-launch` 与 `after-game-launch` Hook 已在 HMCL CE `next` 中执行；其他 Hook 和全部 Patch 目前仍只提供声明与验证，不执行回调或字节码变换。

`PluginCompatibilityRequirements.java` 是 manifest、Store 与 runtime gate 共享的公开不可变输入模型。`PluginCompatibilityEvaluator`、`PluginCompatibilityResult` 和 `PluginCompatibilityStatus` 描述启动器针对当前主机与 provider 状态执行判定的内部流程和结果，不属于插件声明输入，因此不包含在作者参考快照中。

`PluginPermissionService.java` 便于审查权限如何按插件 ID、版本和包 SHA-256 保存。它是包级启动器内部实现，不是插件 SDK 的可调用 API；插件只应通过 `PluginContext` 查询或要求权限，并捕获 `PluginPermissionException` 做功能降级。
