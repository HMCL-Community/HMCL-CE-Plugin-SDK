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
Controllers.navigate(new MyPage());
```

## 创建按钮

```java
JFXButton button = new JFXButton("Click");
button.getStyleClass().add("jfx-button-raised");
button.setOnAction(e -> Controllers.dialog("Clicked", "Plugin"));
```

## 修改窗口

```java
context.getPrimaryStage().setTitle("New title");
```

## 文件读写

```java
Path file = context.getPluginDirectory().resolve("data.json");
Files.writeString(file, "{}");
String content = Files.readString(file);
```

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
  "versions": [
    {
      "version": "1.0.0",
      "packageUrl": "https://github.com/owner/repo/releases/download/v1.0.0/plugin.npl",
      "sha256": "...",
      "minLauncherVersion": "3.17.0",
      "requiredJavaVersion": "17",
      "size": 102400,
      "releaseNotes": "Initial release.",
      "releaseDate": "2026-07-14"
    }
  ]
}
```
