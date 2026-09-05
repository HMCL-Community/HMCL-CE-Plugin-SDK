# Source References

这里复制了 Aura Launcher 的 `AuraPluginSystem` 中最常用的插件源码文件，方便插件作者查看接口和数据模型；
文件保留 `org.jackhuang.hmcl` 等兼容包名。

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
- `PluginPatchInvocation.java`
- `PluginPatchResult.java`
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
- `RuntimePatchEndpoint.java`
- `RuntimePatchWireCodec.java`
- `PluginStoreRegistry.java`
- `PluginStoreManifest.java`
- `PluginStoreItem.java`
- `PluginVersion.java`

这些文件由 `tools/sync-api-references.ps1` 从相邻 Aura Launcher 仓库的 `AuraPluginSystem` 同步。实际编译时
仍应使用 Aura Launcher JAR 作为 `compileOnly` 依赖。

Schema v5 以 `runtime`、`abi` 与 `platforms` 定义语言无关的执行契约；这里的 Java 类型是 Aura Launcher
`next` 当前公开契约的源码快照，并不把 schema v5 限定为 Java 插件格式。`before-game-launch` 与
`after-game-launch` Hook 已在 Aura Launcher `next` 中执行；其他 Hook 仍是声明合同。启动器以受支持的 Agent
instrumentation 运行时可执行 Patch 回调；仅声明 Patch 不会启动该 Agent，未受支持时注册返回
`PATCH_ENGINE_UNAVAILABLE`。参见 [Java Patch 示例](../examples/java-patch/README.md) 和[作者合同](../docs/PLUGIN_DEVELOPMENT.md#patch-执行前提与回调合同)。

`PluginCompatibilityRequirements.java` 是 manifest、Store 与 runtime gate 共享的公开不可变输入模型。`PluginCompatibilityEvaluator`、`PluginCompatibilityResult` 和 `PluginCompatibilityStatus` 描述启动器针对当前主机与 provider 状态执行判定的内部流程和结果，不属于插件声明输入，因此不包含在作者参考快照中。

`PluginPermissionService.java` 便于审查权限如何按插件 ID、版本和包 SHA-256 保存。它是包级启动器内部实现，不是插件 SDK 的可调用 API；插件只应通过 `PluginContext` 查询或要求权限，并捕获 `PluginPermissionException` 做功能降级。
