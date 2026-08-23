# HMCL CE 插件 API 速查表

> HMCL CE 插件 API 仅面向 Java/Kotlin JVM 插件。JavaScript 与 Node.js 运行时不受支持。

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
  "type": "java",
  "permissions": ["mixin"],
  "requiredPermissions": ["mixin"],
  "mixins": ["mixins.com.example.plugin.json"]
}
```

使用 `compileOnly("org.spongepowered:mixin:0.8.7")`，不要把 Mixin 运行时重复打进插件 JAR。含 Mixin 的插件需要重启后才会加载或卸载。

## 发布认证速查

```text
Topic: hmclce
NPL plugin.json: schemaVersion 4
仓库 manifest.json: schemaVersion 2
tag: v<SemVer>
Actions permissions: contents: write
Community publishing: lowercase GitHub topic hmclce plus default-branch manifest.json (schema v2)
```

社区发布不要求逐版本认证材料。启动器在安装前校验清单结构、插件 ID、版本、下载地址、SHA-256、依赖与权限声明；官方源收录（HMCL-CE-Plugin-Store）只是来源标识。
