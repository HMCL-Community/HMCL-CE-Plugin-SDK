# HMCL 插件开发指南

## 插件格式

HMCL 插件是 `.npl` 文件（实际上是标准的 ZIP 压缩包），包含以下结构：

```
example-plugin.npl (ZIP)
├── plugin.json          # 插件清单（必需）
├── classes/             # Java/Kotlin 编译后的类文件
├── libs/                # 依赖的 JAR 文件
└── script.js            # JavaScript 插件入口（如果是 JS 插件）
```

## 插件清单 (plugin.json)

所有插件必须包含 `plugin.json` 文件：

```json
{
  "id": "com.example.myplugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "description": "A sample HMCL plugin",
  "author": "Your Name",
  "type": "java",
  "entrypoint": "com.example.myplugin.MyPlugin",
  "dependencies": [],
  "minLauncherVersion": "3.0.0"
}
```

### 字段说明

- `id`: 插件唯一标识符（必需）
- `name`: 插件显示名称（必需）
- `version`: 插件版本（必需）
- `description`: 插件描述
- `author`: 作者信息
- `type`: 插件类型，可选值：`java`、`kotlin`、`javascript`（必需）
- `entrypoint`: 插件入口点（必需）
  - Java/Kotlin: 完整类名
  - JavaScript: 相对于插件根目录的文件路径
- `dependencies`: 依赖的其他插件 ID 列表
- `minLauncherVersion`: 最低启动器版本要求

## Java/Kotlin 插件开发

### 1. 创建插件类

```java
package com.example.myplugin;

import org.jackhuang.hmcl.plugin.Plugin;
import org.jackhuang.hmcl.plugin.PluginContext;
import org.jackhuang.hmcl.plugin.PluginManifest;

public class MyPlugin implements Plugin {
    
    private PluginManifest manifest;
    private PluginContext context;
    
    @Override
    public void onLoad(PluginContext context) {
        this.context = context;
        this.manifest = context.getManifest();
        
        System.out.println("Plugin loaded: " + manifest.getName());
        
        // 访问启动器 API
        String version = context.getLauncherVersion();
        System.out.println("Launcher version: " + version);
    }
    
    @Override
    public void onEnable() {
        System.out.println("Plugin enabled: " + manifest.getName());
        
        // 在这里初始化插件功能
        // 例如：添加自定义 UI、注册事件监听器等
    }
    
    @Override
    public void onDisable() {
        System.out.println("Plugin disabled: " + manifest.getName());
        
        // 清理资源
    }
    
    @Override
    public void onUnload() {
        System.out.println("Plugin unloaded: " + manifest.getName());
    }
    
    @Override
    public PluginManifest getManifest() {
        return manifest;
    }
}
```

### 2. 编译插件

```bash
# 编译 Java 类
javac -cp HMCL.jar -d classes src/com/example/myplugin/*.java

# 打包成 .npl
cd build
zip -r example-plugin.npl plugin.json classes/ libs/
```

### 3. Kotlin 示例

```kotlin
package com.example.myplugin

import org.jackhuang.hmcl.plugin.Plugin
import org.jackhuang.hmcl.plugin.PluginContext
import org.jackhuang.hmcl.plugin.PluginManifest

class MyPlugin : Plugin {
    
    private lateinit var manifest: PluginManifest
    private lateinit var context: PluginContext
    
    override fun onLoad(context: PluginContext) {
        this.context = context
        this.manifest = context.manifest
        
        println("Plugin loaded: ${manifest.name}")
    }
    
    override fun onEnable() {
        println("Plugin enabled: ${manifest.name}")
    }
    
    override fun onDisable() {
        println("Plugin disabled: ${manifest.name}")
    }
    
    override fun onUnload() {
        println("Plugin unloaded: ${manifest.name}")
    }
    
    override fun getManifest(): PluginManifest = manifest
}
```

## JavaScript 插件开发

### 1. 创建 JavaScript 插件

```javascript
const event = process.argv[2] || process.env.HMCL_PLUGIN_EVENT;

function send(message) {
    process.stdout.write('HMCL_PLUGIN_MESSAGE:' + JSON.stringify({
        protocol: 'hmcl-ui-v1',
        ...message
    }) + '\n');
}

if (event === 'onEnable') {
    send({
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
    });
}
```

### 2. JavaScript 运行时要求

HMCL 固定使用 Node.js v24.18.0。启动器根据操作系统和架构从 Node.js 官方站下载二进制压缩包，解压到 `.hmcl/nodejs/current`。不会读取系统 Node.js、GraalJS、Nashorn 或其他 JSR-223 引擎。

Node.js 与 HMCL JVM 是不同进程，因此 JavaScript 不能使用 `Java.type()` 或直接创建 JavaFX 对象。JavaScript 应使用 `hmcl-ui-v1` 声明页面和事件；HMCL 在 JVM 中代理创建真实 JavaFX 控件。详见 [JAVASCRIPT_UI.md](JAVASCRIPT_UI.md)。

### 3. 打包 JavaScript 插件

```bash
zip -r example-plugin.npl plugin.json script.js
```

## 插件 API

### PluginContext

插件上下文提供访问启动器功能的接口：

```java
// 获取插件清单
PluginManifest getManifest()

// 获取插件目录（解压后的位置）
Path getPluginDirectory()

// 获取插件类加载器
ClassLoader getClassLoader()

// 获取启动器版本
String getLauncherVersion()

// 获取主窗口
Stage getPrimaryStage()

// 获取设置管理器
SettingsManager getSettingsManager()

// 获取数据目录
Path getDataDirectory()
```

### 完全访问权限

**重要**: HMCL 插件系统允许插件对启动器进行任何修改操作。插件可以：

- 访问所有启动器 API
- 修改 UI 界面
- 拦截和修改游戏启动流程
- 访问和修改配置文件
- 执行任意代码

这意味着：
1. **用户需要信任插件作者**
2. **只安装来自可信来源的插件**
3. **插件可能存在安全风险**

## 示例项目

### 简单 UI 插件

```java
import javafx.application.Platform;
import javafx.scene.control.Alert;
import javafx.scene.control.Alert.AlertType;

public class HelloWorldPlugin implements Plugin {
    
    @Override
    public void onEnable() {
        Platform.runLater(() -> {
            Alert alert = new Alert(AlertType.INFORMATION);
            alert.setTitle("Hello World");
            alert.setHeaderText(null);
            alert.setContentText("Hello from plugin!");
            alert.show();
        });
    }
    
    // ... 其他方法
}
```

## 调试插件

1. 在插件代码中使用 `System.out.println()` 或 `LOG.info()`
2. 查看 HMCL 日志文件
3. 使用 Java 调试器连接到 HMCL 进程

## 最佳实践

1. **错误处理**: 始终捕获异常，避免崩溃启动器
2. **资源清理**: 在 `onDisable()` 中清理所有资源
3. **线程安全**: UI 操作使用 `Platform.runLater()`
4. **版本兼容**: 检查最低启动器版本
5. **文档**: 为插件编写使用说明

## 发布插件

1. 测试插件在不同系统和架构上的兼容性
2. 编写详细的 README
3. 指定明确的版本号
4. 提供安全的下载渠道

## 故障排除

### 插件无法加载

- 检查 `plugin.json` 格式是否正确
- 确认 `entrypoint` 类名正确
- 检查是否缺少依赖

### JavaScript 插件不工作

- 在插件管理页下载 HMCL 托管的 Node.js v24.18.0
- 查看 HMCL 中的 JavaScript 引擎状态
- 检查 JavaScript 语法错误

### 插件崩溃

- 查看 HMCL 日志文件
- 添加更多错误处理
- 确保线程安全

## 更多信息

- HMCL 主页: https://hmcl.huangyuhui.net/
- HMCL GitHub: https://github.com/HMCL-dev/HMCL
