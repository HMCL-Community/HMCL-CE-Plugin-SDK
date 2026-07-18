# HMCL Nex Plugin SDK

这个 SDK 目录用于插件作者快速创建、打包、测试和发布 HMCL Nex 插件。

## 目录结构

```text
HMCL-Nex-Plugin-SDK/
├── examples/
│   ├── java-helloworld/          # Java 插件：创建按钮和页面
│   ├── java-mixin/               # Java + Mixin：启动前修改 HMCL 类
│   ├── kotlin-helloworld/        # Kotlin 插件：创建按钮和页面
│   └── javascript-helloworld/    # JavaScript 插件：创建按钮和页面
├── snippets/
│   ├── java/                     # Java 常用调用示例
│   ├── kotlin/                   # Kotlin 常用调用示例
│   └── javascript/               # JavaScript 常用调用示例
├── store/                        # 插件商店发布模板
└── tools/                        # 打包/发布脚本
```

## 插件包格式

`.npl` 是 ZIP 包。必须包含：

```text
plugin.json
libs/your-plugin.jar      # Java/Kotlin 常用
main.js                   # JavaScript 常用
```

`plugin.json` 示例：

```json
{
  "schemaVersion": 2,
  "id": "dev.hmclnex.example.java.helloworld",
  "name": "Java HelloWorld Plugin",
  "version": "1.0.0",
  "type": "java",
  "entrypoint": "dev.hmclnex.example.javahelloworld.JavaHelloWorldPlugin"
}
```

Java/Kotlin 插件可选声明启动前 Mixin 配置：

```json
{
  "schemaVersion": 2,
  "type": "java",
  "entrypoint": "com.example.MyPlugin",
  "mixins": ["mixins.com.example.plugin.json"]
}
```

Mixin 配置及其类必须放在插件 JAR 的资源/类路径中。含 Mixin 的插件只会在它已启用且 HMCL 下次启动时应用；启用、禁用、更新和卸载都应按界面提示重启。

## 编译 Java 示例

```powershell
$env:HMCL_JAR="../HMCL-Nex/HMCL/build/libs/HMCL-<version>.jar"
../HMCL-Nex/gradlew.bat -p examples/java-helloworld packageNpl
```

输出：

```text
build/npl/dev.hmclnex.example.java.helloworld-v1.0.0.npl
```

## 编译 Kotlin 示例

```powershell
$env:HMCL_JAR="../HMCL-Nex/HMCL/build/libs/HMCL-<version>.jar"
../HMCL-Nex/gradlew.bat -p examples/kotlin-helloworld packageNpl
```

输出：

```text
build/npl/dev.hmclnex.example.kotlin.helloworld-v1.0.0.npl
```

## 编译 Mixin 示例

先构建包含插件 API 和 Mixin 宿主的 HMCL JAR，然后打包示例：

```powershell
cd ../HMCL-Nex
./gradlew.bat :HMCL:jar
$env:HMCL_JAR="D:/HMCL-Nex/HMCL/build/libs/HMCL-<version>.jar"
./gradlew.bat -p ../HMCL-Nex-Plugin-SDK/examples/java-mixin packageNpl
```

输出：

```text
examples/java-mixin/build/npl/dev.hmclnex.example.java.mixin-v1.0.0.npl
```

## 打包 JavaScript 示例

```powershell
./tools/package-javascript.ps1
```

输出：

```text
examples/javascript-helloworld/build/npl/dev.hmclnex.example.javascript.helloworld-v1.0.0.npl
```

## 安装测试

1. 启动 HMCL Nex。
2. 左侧主界面点击“插件”。
3. 选择“管理插件”。
4. 点击“安装插件”。
5. 选择 `.npl` 文件。
6. 确认红色风险警告。
7. 安装完成后选择现在重启或稍后重启。

安装前可验证包结构、入口、Mixin 资源、解压大小并生成发布所需摘要：

```powershell
./tools/validate-npl.ps1 ./path/to/plugin.npl
```

## 示例功能

三种语言示例都包含：

- `onLoad/onEnable/onDisable/onUnload` 生命周期。
- 写入插件目录文件。

Java/Kotlin 示例直接创建 JavaFX 控件并调用 HMCL API；Mixin 示例在 HMCL 类定义前注入字节码，然后继续使用相同的插件生命周期。JavaScript 在 HMCL 管理的固定 Node.js 子进程中运行，不能直接调用 JVM 类；它通过 `hmcl-ui-v1` 声明控件树，由 HMCL 创建真实 JavaFX 页面，并通过事件消息更新控件或显示 HMCL 对话框。详见 [JavaScript UI 协议](docs/JAVASCRIPT_UI.md)。

> 本 SDK 对应 [PCL-Nex-Developer/HMCL-Nex](https://github.com/PCL-Nex-Developer/HMCL-Nex) 中的插件系统。SDK 只保存开发文档、示例、打包工具和测试包，不包含启动器源码或运行时缓存。

## 常用入口对象

### PluginContext

```java
context.getManifest();
context.getPluginDirectory();
context.getPackageDirectory();
context.getClassLoader();
context.getLauncherVersion();
context.getPrimaryStage();
context.getLauncherDataDirectory();
context.getDataDirectory();
```

`getPluginDirectory()` / `getPackageDirectory()` 是只应读取的解压包目录；插件持久化文件应写入 `getDataDirectory()`，更新插件时不会被覆盖。

### Controllers

常用：

```java
Controllers.navigate(page);
Controllers.dialog("text", "title");
Controllers.getSettingsPage();
Controllers.getDownloadPage();
Controllers.getStage();
```

### GameDirectoryManager

```java
GameDirectoryManager.getSelectedRepository();
GameDirectoryManager.getSelectedGameDirectory();
GameDirectoryManager.selectedInstanceProperty();
```

## 发布到插件商店

1. 打包 `.npl`。
2. 创建 GitHub Release 并上传 `.npl`。
3. 计算 SHA-256：

```powershell
Get-FileHash plugin.npl -Algorithm SHA256
```

4. 在插件仓库根目录创建 `manifest.json`，可复制：

```text
store/manifest.template.json
```

5. 到插件商店仓库添加插件条目：

```text
store/plugins-entry.template.json
```

官方 HMCL Nex 插件商店仓库：

```text
https://github.com/PCL-Nex-Developer/HMCL-Nex-Plugin-Store
```

## 自动发布模板

复制：

```text
store/github-release-workflow.yml
```

到插件仓库：

```text
.github/workflows/release.yml
```

打 tag 后自动构建并创建 Release。

## 安全提醒

HMCL Nex 插件没有沙箱，Mixin 还能在类加载前修改启动器字节码。请只发布和安装可信插件，并为注入点设置明确的 `defaultRequire`，避免静默失效。
