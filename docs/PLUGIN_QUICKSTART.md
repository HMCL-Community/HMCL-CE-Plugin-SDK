# HMCL 插件系统 - 快速入门

## 5 分钟创建你的第一个插件

### 准备工作

你需要：
- HMCL Nex 26.8-beta.3-fix 及以上
- 文本编辑器
- 压缩工具（如 7-Zip、WinRAR 或命令行 `zip`）

---

## 创建 JavaScript 插件（最简单）

### 1. 创建插件目录

```
my-first-plugin/
├── plugin.json
└── main.js
```

### 2. 编写 plugin.json

```json
{
  "schemaVersion": 4,
  "id": "com.myname.firstplugin",
  "name": "我的第一个插件",
  "version": "1.0.0",
  "description": "这是我的第一个 HMCL 插件",
  "author": "你的名字",
  "type": "javascript",
  "entrypoint": "main.js",
  "dependencies": [],
  "permissions": ["launcher-ui"],
  "requiredPermissions": [],
  "launcherVersion": ">=26.8-beta.3-fix"
}
```

### 3. 编写 main.js

```javascript
const event = process.argv[2] || process.env.HMCL_PLUGIN_EVENT;

if (event === 'onEnable') {
    process.stdout.write('HMCL_PLUGIN_MESSAGE:' + JSON.stringify({
        protocol: 'hmcl-ui-v1',
        sidebar: {
            title: '我的第一个插件',
            page: {
                type: 'vbox',
                children: [
                    { type: 'title', text: '欢迎' },
                    { type: 'label', text: '这是由 JavaScript 声明的 JavaFX 页面。' }
                ]
            }
        }
    }) + '\n');
}
```

### 4. 打包插件

#### Windows (PowerShell)
```powershell
Compress-Archive -Path my-first-plugin\* -DestinationPath my-first-plugin.npl
```

#### Linux/macOS
```bash
cd my-first-plugin
zip -r ../my-first-plugin.npl *
```

#### 手动打包
- 选中 `plugin.json` 和 `main.js`
- 右键 → 发送到 → 压缩文件
- 重命名为 `my-first-plugin.npl`

### 5. 安装插件

1. 打开 HMCL
2. 进入 **设置** → **插件管理**
3. 点击 **安装插件**
4. 选择 `my-first-plugin.npl`
5. 在完整权限窗口中决定是否允许 `launcher-ui`
6. 确认安装并重启 HMCL

### 6. 查看效果

重启后，授予 `launcher-ui` 时会显示插件页面；拒绝时插件生命周期仍可运行，但受保护的界面功能必须降级。

---

## 创建 Java 插件

### 1. 创建项目结构

```
my-java-plugin/
├── plugin.json
├── src/
│   └── com/
│       └── myname/
│           └── plugin/
│               └── MyPlugin.java
└── libs/
    └── my-java-plugin.jar   # 编译后生成
```

### 2. 编写源代码

`MyPlugin.java`:

```java
package com.myname.plugin;

import org.jackhuang.hmcl.plugin.Plugin;
import org.jackhuang.hmcl.plugin.PluginContext;
import org.jackhuang.hmcl.plugin.PluginManifest;
import org.jackhuang.hmcl.plugin.PluginPermission;
import org.jackhuang.hmcl.plugin.PluginPermissionException;
import javafx.application.Platform;
import javafx.scene.control.Alert;
import javafx.scene.control.Alert.AlertType;

public class MyPlugin implements Plugin {
    
    private PluginManifest manifest;
    private PluginContext context;
    
    @Override
    public void onLoad(PluginContext context) {
        this.context = context;
        this.manifest = context.getManifest();
        System.out.println("插件已加载：" + manifest.getName());
    }
    
    @Override
    public void onEnable() {
        if (!context.isPermissionGranted(PluginPermission.LAUNCHER_UI)) {
            System.out.println("用户拒绝 launcher-ui；插件继续运行，但不显示欢迎窗口");
            return;
        }

        Platform.runLater(() -> {
            try {
                context.requirePermission(PluginPermission.LAUNCHER_UI);
                Alert alert = new Alert(AlertType.INFORMATION);
                alert.setTitle("欢迎");
                alert.setHeaderText("Java 插件启动");
                alert.setContentText("你的 Java 插件正在运行！");
                alert.initOwner(context.getPrimaryStage());
                alert.show();
            } catch (PluginPermissionException exception) {
                System.out.println("launcher-ui 已被撤销；跳过欢迎窗口");
            }
        });
    }
    
    @Override
    public void onDisable() {
        System.out.println("插件已禁用");
    }
    
    @Override
    public void onUnload() {
        System.out.println("插件已卸载");
    }
    
    @Override
    public PluginManifest getManifest() {
        return manifest;
    }
}
```

### 3. 编译

```bash
# 使用 HMCL.jar 作为类路径
mkdir -p build/classes libs
javac -cp HMCL.jar -d build/classes src/com/myname/plugin/MyPlugin.java
jar --create --file libs/my-java-plugin.jar -C build/classes .
```

### 4. 创建 plugin.json

```json
{
  "schemaVersion": 4,
  "id": "com.myname.javaplugin",
  "name": "我的 Java 插件",
  "version": "1.0.0",
  "description": "使用 Java 开发的插件",
  "author": "你的名字",
  "type": "java",
  "entrypoint": "com.myname.plugin.MyPlugin",
  "dependencies": [],
  "permissions": ["launcher-ui"],
  "requiredPermissions": [],
  "launcherVersion": ">=26.8-beta.3-fix"
}
```

### 5. 打包和安装

```bash
cd my-java-plugin
jar --create --file ../my-java-plugin.npl plugin.json libs
```

然后在 HMCL 中安装、确认权限并重启。新包在当前进程只显示为待重启，不会立即构造或执行入口类。

安装时权限开关默认关闭。每次更新也会重新出现完整授权窗口，旧授权与新版本声明的交集只作为预选，新增权限默认关闭；取消窗口不会更新插件或改变现有授权。所有安装和更新都等待重启发布，当前进程不会执行新 artifact。插件运行期间用户还可以撤权，因此权限判断和异常处理不能只写在安装说明里，必须落实到每次受保护操作。

---

## JavaScript 运行时安装

如果插件管理界面显示 "JavaScript 引擎不可用"：

1. 打开“插件管理”。
2. 点击“下载 Node.js 运行时”。
3. HMCL 将自动下载适合当前系统和架构的 Node.js v24.18.0 二进制压缩包。
4. 不需要也不会使用系统安装的 Node.js。

---

## 下一步：用 Mixin 修改 HMCL

如果需要在 HMCL 类加载前注入逻辑，直接从 `examples/java-mixin` 复制工程。HMCL Nex 只安装和执行 schema v4 插件。Mixin 插件安装或启用后必须重启，且只有全部必要权限获批才会执行；可选权限仍可独立拒绝，只会停用对应功能。运行中撤销必要权限会停止普通生命周期，已经应用的字节码要到下次启动才会消失。

---

## 常见问题

### Q: 插件无法加载？

**A:** 检查：
1. `plugin.json` 格式是否正确（使用 JSON 验证器）
2. 文件编码是否为 UTF-8
3. `.npl` 文件是否为有效的 ZIP 文件
4. `entrypoint` 路径是否正确

### Q: JavaScript 插件不工作？

**A:** 
1. 检查插件管理界面的 JavaScript 引擎状态
2. 使用插件管理页安装 HMCL 托管的 Node.js 后重启 HMCL
3. 查看 HMCL 日志文件

### Q: Java 插件找不到类？

**A:**
1. 确认插件本体 JAR 位于 NPL 的 `libs/` 中
2. 检查 `entrypoint` 完整类名与 Java 包名完全一致
3. 使用 `jar --list --file libs/your-plugin.jar` 确认入口 `.class` 已打入 JAR

### Q: 如何调试插件？

**A:**
1. 使用 `System.out.println()`（Java）或 `process.stdout.write()`（JavaScript）
2. 查看 HMCL 日志文件
3. 在代码中添加 try-catch 捕获异常

---

## 下一步

- 阅读完整的 [插件开发指南](PLUGIN_DEVELOPMENT.md)
- 查看 [插件开发指南](PLUGIN_DEVELOPMENT.md)
- 研究 `examples/` 中的三种语言完整示例插件
- 探索 HMCL API 修改界面和功能

---

## 需要帮助？

- HMCL GitHub: https://github.com/HMCL-dev/HMCL
- HMCL 文档: https://docs.hmcl.net/

祝你插件开发愉快！🚀
