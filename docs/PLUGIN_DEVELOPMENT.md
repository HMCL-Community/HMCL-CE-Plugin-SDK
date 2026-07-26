# HMCL 插件开发指南

## 插件格式

HMCL 插件是 `.npl` 文件（实际上是标准的 ZIP 压缩包），包含以下结构：

```
example-plugin.npl (ZIP)
├── plugin.json          # 插件清单（必需）
├── libs/                # 插件本体与依赖的 JAR 文件
└── script.js            # JavaScript 插件入口（如果是 JS 插件）
```

## 插件清单 (plugin.json)

所有插件必须包含 `plugin.json` 文件：

```json
{
  "schemaVersion": 4,
  "id": "com.example.myplugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "description": "A sample HMCL plugin",
  "author": "Your Name",
  "type": "java",
  "entrypoint": "com.example.myplugin.MyPlugin",
  "dependencies": [],
  "permissions": ["filesystem", "launcher-ui"],
  "requiredPermissions": ["launcher-ui"],
  "launcherVersion": ">=26.8-beta.3-fix <27.0",
  "mixins": []
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
- `dependencies`: 依赖插件列表；可使用旧的 ID 字符串，推荐使用 `{ "id": "...", "version": ">=1.0.0 <2.0.0" }`
- `permissions`: schema v4 必填的全部权限声明数组，即使为空也必须填写 `[]`
- `requiredPermissions`: schema v4 必填的必要权限子集；必要权限默认授予并锁定，不能单独关闭
- `launcherVersion`: schema v4 必填的 HMCL Nex 版本约束，支持精确版本、`*`、`<`、`<=`、`>`、`>=` 和组合范围
- `schemaVersion`: 必须为 `4`；HMCL Nex 不安装或执行 schema v1-v3 插件
- `mixins`: Java/Kotlin 插件的 Mixin 配置资源列表；声明后启停、更新、卸载需要重启

## Java/Kotlin Mixin 插件

HMCL Nex 在正常 `EntryPoint` 执行前扫描已启用插件。发现 Mixin 配置后，首个 JVM 会自动用当前 HMCL JAR 作为 `-javaagent` 启动第二个 JVM；Agent 的 `premain` 把插件根资源和 JAR 追加到系统类加载器搜索路径，在 `Main` 加载前初始化 SpongePowered Mixin 0.8.7 并注册变换器。不要在 `onLoad()` 中自行调用 `MixinBootstrap`，那时目标类通常已经加载。

这种方式让 HMCL、JavaFX、插件入口和 Mixin 类共享唯一的系统类加载器类身份。Agent 已加入的类路径不能在运行中撤销，因此含 Mixin 插件的启用、禁用、更新和卸载都必须等待重启。

`plugin.json`：

```json
{
  "schemaVersion": 4,
  "id": "com.example.mixinplugin",
  "name": "Mixin Plugin",
  "version": "1.0.0",
  "type": "java",
  "entrypoint": "com.example.PluginMain",
  "dependencies": [],
  "permissions": ["mixin"],
  "requiredPermissions": ["mixin"],
  "launcherVersion": ">=26.8-beta.3-fix",
  "mixins": ["mixins.com.example.plugin.json"]
}
```

## 权限声明

HMCL Nex 在安装或更新前展示插件声明的权限，并在商店包下载后把实际 `plugin.json` 与商店版本清单交叉校验。有效权限是开发者声明与用户授权的交集；未声明的能力不会显示开关，也不能通过官方 SDK 使用。支持的权限 ID：

- `filesystem`: 读取或写入插件包资源和私有数据目录之外的文件
- `network`: 发起网络请求或建立网络连接
- `process`: 创建、控制或检查外部进程
- `account`: 读取或修改 HMCL 账户信息
- `game-launch`: 读取实例、改变启动参数或触发游戏启动
- `launcher-ui`: 添加或修改 HMCL 界面
- `mixin`: 在启动器类定义前应用声明的 Mixin；含 `mixins` 的 schema v4 插件必须声明并列为必要权限
- `clipboard`: 读取或写入系统剪贴板
- `native-code`: 加载 JNI、本地库或其他原生代码

授权绑定插件 ID、版本和 `.npl` SHA-256。首次安装时必要权限默认开启且不可关闭，可选权限默认关闭。每次更新都会显示新的完整授权窗口，旧版本仍声明的可选授权作为预选；新增可选权限默认关闭，从可选升级为必要的权限会明确标记。相同版本的包如果 SHA-256 发生变化，也必须重新确认完整授权窗口。

所有新安装和更新都只写入待重启计划。确认窗口关闭后，当前进程不会注册、构造或执行新 artifact；下一次启动完成包事务与权限绑定后才进入生命周期。

`PluginContext` 在调用受保护的官方 API 时动态检查授权，拒绝时抛出 `PluginPermissionException`。用户可以在插件管理页运行期撤权，因此插件必须在每次操作时检查，并让对应功能降级，不能让拒绝异常从 `onLoad()` 或 `onEnable()` 逸出。

schema v4 Mixin 插件只把 `requiredPermissions` 作为原子启动门槛，且 `mixin` 本身必须是必要权限。必要权限完整授予并由启动前 Agent 验证精确包身份后，HMCL 才会加载入口点；可选权限被拒绝时插件仍运行，对应功能必须自行降级。HMCL Nex 不安装或执行旧 schema 插件。

这不是 JVM 或操作系统级沙箱。Java/Kotlin 插件与 HMCL 共享 JVM，Node.js 插件也是普通系统进程；直接使用 JDK、JavaFX、Mixin 或启动器内部类不受 `PluginContext` 强制拦截。插件作者仍必须完整声明实际能力，用户也应只安装可信插件。

## 依赖版本

```json
"dependencies": [
  {
    "id": "dev.hmclnex.example.base",
    "version": ">=1.2.0 <2.0.0"
  }
]
```

版本约束支持 `*`、精确版本或 `=1.2.3`，以及 `<`、`<=`、`>`、`>=`。多个条件用空格或逗号连接。插件商店会递归选择满足约束的最高兼容版本；缺失依赖、冲突约束和循环依赖都会在写入插件目录前终止安装。

Mixin 配置：

```json
{
  "required": true,
  "minVersion": "0.8.7",
  "package": "com.example.mixin",
  "compatibilityLevel": "JAVA_17",
  "mixins": ["LauncherMixin"],
  "injectors": { "defaultRequire": 1 }
}
```

Gradle 依赖应使用 `compileOnly("org.spongepowered:mixin:0.8.7")`，不要把 Mixin 本体打进插件 JAR。完整工程见 `examples/java-mixin`。

开发期若注入配置导致 HMCL 无法启动，可用 `-Dhmcl.plugin.mixins.disabled=true` 暂停所有插件 Mixin，进入管理页处理问题插件。

## Java/Kotlin 插件开发

### 1. 创建插件类

```java
package com.example.myplugin;

import org.jackhuang.hmcl.plugin.Plugin;
import org.jackhuang.hmcl.plugin.PluginContext;
import org.jackhuang.hmcl.plugin.PluginManifest;
import org.jackhuang.hmcl.plugin.PluginPermission;
import org.jackhuang.hmcl.plugin.PluginPermissionException;

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

        if (!context.isPermissionGranted(PluginPermission.LAUNCHER_UI)) {
            System.out.println("Launcher UI permission denied; UI feature disabled");
            return;
        }

        try {
            context.registerSidebarItem("My Plugin", () -> {
                // 创建并跳转到插件页面。
            });
        } catch (PluginPermissionException exception) {
            // 用户可能在查询后立刻撤权；保持插件生命周期可用。
            System.out.println("Launcher UI permission changed: " + exception.getReason());
        }
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
# 编译 Java 类并生成插件 JAR
mkdir -p build/classes build/package/libs
javac -cp HMCL.jar -d build/classes src/com/example/myplugin/*.java
jar --create --file build/package/libs/example-plugin.jar -C build/classes .

# 打包成 .npl
cp plugin.json build/package/plugin.json
cd build/package
jar --create --file ../../example-plugin.npl plugin.json libs
```

### 3. Kotlin 示例

```kotlin
package com.example.myplugin

import org.jackhuang.hmcl.plugin.Plugin
import org.jackhuang.hmcl.plugin.PluginContext
import org.jackhuang.hmcl.plugin.PluginManifest
import org.jackhuang.hmcl.plugin.PluginPermission
import org.jackhuang.hmcl.plugin.PluginPermissionException

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
        if (!context.isPermissionGranted(PluginPermission.LAUNCHER_UI)) {
            println("Launcher UI permission denied; UI feature disabled")
            return
        }

        try {
            context.registerSidebarItem("My Plugin") {
                // 创建并跳转到插件页面。
            }
        } catch (exception: PluginPermissionException) {
            println("Launcher UI permission changed: ${exception.reason}")
        }
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

// 获取主窗口（需要 launcher-ui）
Stage getPrimaryStage()

// 获取启动器全局数据目录（需要 filesystem）
Path getLauncherDataDirectory()

// 获取插件私有持久化数据目录
Path getDataDirectory()

// 查询开发者声明和当前有效授权
Set<PluginPermission> getDeclaredPermissions()
Set<PluginPermission> getGrantedPermissions()
boolean isPermissionGranted(PluginPermission permission)

// 要求权限；未声明或用户拒绝时抛出 PluginPermissionException
void requirePermission(PluginPermission permission)

// 注册插件侧栏入口（需要 launcher-ui）
void registerSidebarItem(String title, Runnable onAction)
```

### 权限边界

HMCL 官方插件 API 会按当前授权门控敏感能力，例如：

- `getPrimaryStage()`、`registerSidebarItem()` 需要 `launcher-ui`
- `getLauncherDataDirectory()` 需要 `filesystem`
- `getDataDirectory()` 仅返回插件私有持久化目录，不需要 `filesystem`
- `requirePermission()` 可用于调用未封装的启动器 API 前进行同样的动态检查

`PluginPermissionException.getReason()` 区分 `NOT_DECLARED` 与 `USER_DENIED`。前者表示开发者没有在清单申请，用户无法补授；后者表示权限已申请但当前未获用户同意。

由于 Java/Kotlin 插件与 HMCL 同 JVM，这层机制不能阻止插件绕过 SDK 直接执行代码。权限声明和 SDK 门控用于让守规插件形成清晰、可撤销的能力边界，不替代对插件来源的信任判断。

## 示例项目

### 简单 UI 插件

```java
import javafx.application.Platform;
import javafx.scene.control.Alert;
import javafx.scene.control.Alert.AlertType;

public class HelloWorldPlugin implements Plugin {
    private PluginContext context;

    @Override
    public void onLoad(PluginContext context) {
        this.context = context;
    }

    @Override
    public void onEnable() {
        if (!context.isPermissionGranted(PluginPermission.LAUNCHER_UI)) {
            return;
        }

        Platform.runLater(() -> {
            try {
                context.requirePermission(PluginPermission.LAUNCHER_UI);
                Alert alert = new Alert(AlertType.INFORMATION);
                alert.setTitle("Hello World");
                alert.setHeaderText(null);
                alert.setContentText("Hello from plugin!");
                alert.initOwner(context.getPrimaryStage());
                alert.show();
            } catch (PluginPermissionException exception) {
                System.out.println("UI permission revoked; alert skipped");
            }
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
6. **Mixin 稳定性**: 优先注入稳定方法，设置 `required`/`defaultRequire`，不要修改 `org.spongepowered.asm` 宿主包

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
