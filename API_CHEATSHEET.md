# Aura Launcher 插件 API 速查表

> 本分支对应 Aura Launcher `next` 的 schema-v5 预发布合同。Schema v5 是语言中立的 runtime、ABI 与 platform
> 合同；本页列出的 Java API 是当前内置 `java` provider 的基线，并不把 schema v5 限定为 Java-only。
> SDK `schema-v4` 仍是稳定、默认分支，schema-v4 包也仍可在 `next` 上运行。

## 兼容性清单

```json
{
  "schemaVersion": 5,
  "type": "java",
  "runtime": "java",
  "abi": 2,
  "platforms": []
}
```

- `runtime`：规范的小写 provider ID；当前仅 `java` provider 内置可用。
- `abi`：当前示例使用 ABI 2。
- `platforms`：可省略或为空表示不限平台；非空时使用 `windows-x64`、`linux-arm64`、`macos` 等规范值。
- .NET、QuickJS/WASM、Python 和原生包属于 schema-v5 扩展范围，但当前里程碑未提供对应 provider。

```java
manifest.getRuntime();
manifest.getAbi();
manifest.getPlatforms();
manifest.getHooks();
manifest.getPatches();
manifest.getCapabilityLevel();
```

## 生命周期

```java
void onLoad(PluginContext context)
void onEnable()
void onDisable()
default void onUnload()
PluginManifest getManifest()
```

## 权限

```java
if (context.isPermissionGranted(PluginPermission.LAUNCHER_UI)) {
    context.registerSidebarItem("My Plugin", () -> Controllers.dialog("Ready", "Plugin"));
}

try {
    context.requirePermission(PluginPermission.FILESYSTEM);
    Files.writeString(context.getLauncherDataDirectory().resolve("plugin.txt"), "ok");
} catch (PluginPermissionException exception) {
    // 权限可能在运行期被撤销。
}
```

常用查询：

```java
context.getManifest();
context.getLauncherVersion();
context.getPackageDirectory();
context.getDataDirectory();
context.getPrimaryStage();
context.getDeclaredPermissions();
context.getGrantedPermissions();
context.getPluginDependencies();
```

## 侧栏页面

```java
context.registerSidebarPage("My Page", MyPage::new);
Controllers.navigate(new MyPage());
```

页面实现 `DecoratorPage`，所有 JavaFX 更新都应在 JavaFX 线程执行。

## Mixin

```json
{
  "schemaVersion": 5,
  "type": "java",
  "runtime": "java",
  "abi": 2,
  "permissions": ["mixin"],
  "requiredPermissions": ["mixin"],
  "mixins": ["mixins.com.example.plugin.json"]
}
```

使用 `compileOnly("org.spongepowered:mixin:0.8.7")`，不要把 Mixin 运行时重复打进插件 JAR。含 Mixin 的插件需要重启后才会加载或卸载。

## Hook 与 Patch

- `hooks` 需要 `launcher-hook` 同时出现在 `permissions` 与 `requiredPermissions`。
- `patches` 需要 `launcher-patch` 同时出现在 `permissions` 与 `requiredPermissions`。
- Aura Launcher `next` 会分发已支持的游戏启动 Hook；其他 Hook 仍是声明合同，Patch 字节码执行引擎尚未提供。

## 发布速查

```text
Topic: hmclce
NPL plugin.json: schemaVersion 5, runtime java, abi 2
仓库 manifest.json: schemaVersion 2, pluginApiVersion 5
tag: v<SemVer>
Actions permissions: contents: write
Community publishing: lowercase GitHub topic hmclce plus default-branch manifest.json (schema v2)
```

Store 的版本条目必须与 NPL 的 ID、版本、schema、权限、依赖、runtime、ABI 和规范化 platforms 一致。
社区发布不要求逐版本认证材料；官方源收录（Aura-Launcher-Plugin-Store）只是来源标识。
