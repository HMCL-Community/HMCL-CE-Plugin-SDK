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

## JavaScript 导入 Java 类

```javascript
var Controllers = Java.type('org.jackhuang.hmcl.ui.Controllers');
var JFXButton = Java.type('com.jfoenix.controls.JFXButton');
var VBox = Java.type('javafx.scene.layout.VBox');
```

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
