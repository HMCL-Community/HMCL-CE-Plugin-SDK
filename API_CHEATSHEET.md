# HMCL Nex Plugin SDK API Cheat Sheet

## 生命周期

```java
void onLoad(PluginContext context)
void onEnable()
void onDisable()
default void onUnload()
PluginManifest getManifest()
```

## 创建页面

Java 页面必须实现 `DecoratorPage`：

```java
public final class MyPage extends VBox implements DecoratorPage {
    private final ReadOnlyObjectWrapper<State> state = new ReadOnlyObjectWrapper<>(State.fromTitle("My Page"));

    @Override
    public ReadOnlyObjectProperty<State> stateProperty() {
        return state.getReadOnlyProperty();
    }
}
```

跳转：

```java
try {
    context.requirePermission(PluginPermission.LAUNCHER_UI);
    Controllers.navigate(new MyPage());
} catch (PluginPermissionException exception) {
    // 用户拒绝或运行中撤权：跳过 UI 功能。
}
```

## 创建按钮

```java
JFXButton button = new JFXButton("Click");
button.getStyleClass().add("jfx-button-raised");
button.setOnAction(e -> {
    try {
        context.requirePermission(PluginPermission.LAUNCHER_UI);
        Controllers.dialog("Clicked", "Plugin");
    } catch (PluginPermissionException exception) {
        // 页面可能在撤权前已经打开。
    }
});
```

## 修改窗口

```java
try {
    context.getPrimaryStage().setTitle("New title");
} catch (PluginPermissionException exception) {
    // launcher-ui 未授权。
}
```

## 文件读写

```java
Path file = context.getDataDirectory().resolve("data.json");
Files.writeString(file, "{}");
String content = Files.readString(file);
```

`getPluginDirectory()` 是解压后的包资源目录，更新时会替换；可写持久化数据使用 `getDataDirectory()`。

## 权限与插件依赖

`plugin.json` 使用 schema v4：

```json
{
  "schemaVersion": 4,
  "permissions": ["filesystem", "launcher-ui"],
  "requiredPermissions": ["launcher-ui"],
  "launcherVersion": ">=26.8-beta.3-fix <27.0",
  "dependencies": [
    { "id": "dev.hmclnex.example.base", "version": ">=1.2.0 <2.0.0" }
  ]
}
```

运行时查询：

```java
context.getPermissions();
context.getDeclaredPermissions();
context.getRequiredPermissions();
context.getOptionalPermissions();
context.getGrantedPermissions();
context.declaresPermission(PluginPermission.FILESYSTEM);
context.isPermissionGranted(PluginPermission.LAUNCHER_UI);
context.requirePermission(PluginPermission.LAUNCHER_UI);
context.getPluginDependencies();
```

`getPermissions()` / `getDeclaredPermissions()` 是全部声明，`getRequiredPermissions()` 是必要权限，`getOptionalPermissions()` 是可选权限，`getGrantedPermissions()` 是当前有效授权。必要权限由 HMCL 锁定授予；可选权限会动态变化，调用受保护接口时应捕获 `PluginPermissionException` 并降级。

首次安装时必要权限默认开启且不可关闭，可选权限默认关闭。每次更新都重新显示完整授权窗口：仍声明的旧可选授权作为预选，新增可选权限默认关闭，可选权限升级为必要权限时会作为新增必要授权标记。取消窗口不会安装包或改写授权。

所有新安装和更新都进入待重启状态；当前进程不会注册、构造或执行新 artifact。

授权绑定插件 ID、版本和 `.npl` SHA-256，只门控 HMCL 官方 SDK 接口，不是 JVM 或操作系统级沙箱。

## Mixin

`plugin.json`：

```json
"permissions": ["mixin"],
"requiredPermissions": ["mixin"],
"mixins": ["mixins.com.example.plugin.json"]
```

schema v4 Mixin 插件只有在当前包的全部必要权限获批，并由启动前 Agent 验证精确版本与 SHA-256 后才执行；可选权限仍可独立关闭。

Gradle：

```kotlin
repositories { maven("https://repo.spongepowered.org/repository/maven-public/") }
dependencies { compileOnly("org.spongepowered:mixin:0.8.7") }
```

Mixin 配置建议至少设置 `required: true`、`compatibilityLevel: JAVA_17` 和 `injectors.defaultRequire: 1`。

## 列出实例

```java
HMCLGameRepository repository = GameDirectoryManager.getSelectedRepository();
repository.getVersions().forEach(version -> System.out.println(version.getId()));
```

## 跳转内置页面

```java
Controllers.navigate(Controllers.getSettingsPage());
Controllers.getDownloadPage().showGameDownloads();
Controllers.navigate(Controllers.getDownloadPage());
```

## JavaScript UI

JavaScript 使用 HMCL 管理的 Node.js v24.18.0 子进程，不能使用 `Java.type()` 或直接实例化 JavaFX 类。输出带协议前缀的单行 JSON 来声明 JavaFX 页面：

```javascript
process.stdout.write('HMCL_PLUGIN_MESSAGE:' + JSON.stringify({
  protocol: 'hmcl-ui-v1',
  sidebar: {
    title: 'My Plugin',
    page: {
      type: 'vbox',
      children: [
        { type: 'title', text: 'My Plugin' },
        { type: 'button', text: 'Run', event: 'run', primary: true }
      ]
    }
  }
}) + '\n');
```

完整控件、事件和响应动作见 [docs/JAVASCRIPT_UI.md](docs/JAVASCRIPT_UI.md)。

## 插件商店 manifest

```json
{
  "schemaVersion": 2,
  "readmeUrl": "https://raw.githubusercontent.com/owner/repo/main/README.md",
  "versions": [
    {
      "version": "1.0.0",
      "packageUrl": "https://github.com/owner/repo/releases/download/v1.0.0/plugin.npl",
      "sha256": "...",
      "launcherVersion": ">=26.8-beta.3-fix",
      "requiredJavaVersion": "17",
      "pluginApiVersion": 4,
      "permissions": ["filesystem", "launcher-ui"],
      "requiredPermissions": ["launcher-ui"],
      "dependencies": [],
      "size": 102400,
      "releaseNotes": "Initial release.",
      "releaseDate": "2026-07-14"
    }
  ]
}
```
