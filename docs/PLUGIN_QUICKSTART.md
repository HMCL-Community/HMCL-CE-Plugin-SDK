# HMCL 插件系统 - 快速入门

## 5 分钟创建你的第一个插件

### 准备工作

你需要：
- HMCL 启动器（3.0+）
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
  "id": "com.myname.firstplugin",
  "name": "我的第一个插件",
  "version": "1.0.0",
  "description": "这是我的第一个 HMCL 插件",
  "author": "你的名字",
  "type": "javascript",
  "entrypoint": "main.js"
}
```

### 3. 编写 main.js

```javascript
function onLoad(context) {
    print("插件已加载！");
    print("HMCL 版本: " + context.getLauncherVersion());
}

function onEnable() {
    print("插件已启用！");
    
    // 导入 JavaFX 类
    var Platform = Java.type("javafx.application.Platform");
    var Alert = Java.type("javafx.scene.control.Alert");
    var AlertType = Java.type("javafx.scene.control.Alert$AlertType");
    
    // 显示对话框
    Platform.runLater(function() {
        var alert = new Alert(AlertType.INFORMATION);
        alert.setTitle("欢迎");
        alert.setHeaderText("插件启动成功");
        alert.setContentText("恭喜！你的第一个插件正在运行！");
        alert.show();
    });
}

function onDisable() {
    print("插件已禁用");
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
5. 点击 **启用**

### 6. 查看效果

启用后会弹出对话框显示 "恭喜！你的第一个插件正在运行！"

---

## 创建 Java 插件

### 1. 创建项目结构

```
my-java-plugin/
├── plugin.json
└── classes/
    └── com/
        └── myname/
            └── plugin/
                └── MyPlugin.class
```

### 2. 编写源代码

`MyPlugin.java`:

```java
package com.myname.plugin;

import org.jackhuang.hmcl.plugin.Plugin;
import org.jackhuang.hmcl.plugin.PluginContext;
import org.jackhuang.hmcl.plugin.PluginManifest;
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
        Platform.runLater(() -> {
            Alert alert = new Alert(AlertType.INFORMATION);
            alert.setTitle("欢迎");
            alert.setHeaderText("Java 插件启动");
            alert.setContentText("你的 Java 插件正在运行！");
            alert.initOwner(context.getPrimaryStage());
            alert.show();
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
javac -cp HMCL.jar -d classes MyPlugin.java
```

### 4. 创建 plugin.json

```json
{
  "id": "com.myname.javaplugin",
  "name": "我的 Java 插件",
  "version": "1.0.0",
  "description": "使用 Java 开发的插件",
  "author": "你的名字",
  "type": "java",
  "entrypoint": "com.myname.plugin.MyPlugin"
}
```

### 5. 打包和安装

```bash
cd my-java-plugin
zip -r ../my-java-plugin.npl plugin.json classes/
```

然后在 HMCL 中安装。

---

## JavaScript 运行时安装

如果插件管理界面显示 "JavaScript 引擎不可用"：

### Windows

1. 访问 https://nodejs.org/
2. 下载 Windows Installer
3. 运行安装程序
4. 重启 HMCL

### macOS

```bash
# 使用 Homebrew
brew install node

# 或从官网下载
open https://nodejs.org/
```

### Linux

```bash
# Ubuntu/Debian
sudo apt install nodejs npm

# Fedora
sudo dnf install nodejs npm

# Arch Linux
sudo pacman -S nodejs npm
```

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
2. 安装 Node.js 后重启 HMCL
3. 查看 HMCL 日志文件

### Q: Java 插件找不到类？

**A:**
1. 确认 `classes/` 目录结构正确
2. 检查包名和目录结构是否匹配
3. 确认类已编译（`.class` 文件存在）

### Q: 如何调试插件？

**A:**
1. 使用 `System.out.println()` (Java) 或 `print()` (JavaScript)
2. 查看 HMCL 日志文件
3. 在代码中添加 try-catch 捕获异常

---

## 下一步

- 阅读完整的 [插件开发指南](PLUGIN_DEVELOPMENT.md)
- 查看 [插件系统文档](PLUGIN_SYSTEM.md)
- 研究 `docs/examples/` 中的示例插件
- 探索 HMCL API 修改界面和功能

---

## 需要帮助？

- HMCL GitHub: https://github.com/HMCL-dev/HMCL
- HMCL 文档: https://docs.hmcl.net/

祝你插件开发愉快！🚀
