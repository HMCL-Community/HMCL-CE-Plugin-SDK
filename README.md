# HMCL Nex Plugin SDK

这个 SDK 目录用于插件作者快速创建、打包、测试和发布 HMCL Nex 插件。

## 目录结构

```text
HMCL-Nex-Plugin-SDK/
├── examples/
│   ├── java-helloworld/          # Java 插件：创建按钮和页面
│   ├── java-mixin/               # Java + Mixin：启动前修改 HMCL 类
│   ├── kotlin-helloworld/        # Kotlin 插件：创建按钮和页面
│   ├── javascript-helloworld/    # JavaScript 插件：创建按钮和页面
│   └── offline-unlocker/         # 真实案例：Mixin 解锁离线登录，含 RED/GREEN 回归脚本
├── snippets/
│   ├── java/                     # Java 常用调用示例
│   ├── kotlin/                   # Kotlin 常用调用示例
│   └── javascript/               # JavaScript 常用调用示例
├── store/                        # 插件商店发布模板
│   └── github-release-workflow.yml # GitHub Release 自动发布工作流
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
  "schemaVersion": 4,
  "id": "dev.hmclnex.example.java.helloworld",
  "name": "Java HelloWorld Plugin",
  "version": "1.0.0",
  "type": "java",
  "entrypoint": "dev.hmclnex.example.javahelloworld.JavaHelloWorldPlugin",
  "dependencies": [],
  "permissions": ["launcher-ui"],
  "requiredPermissions": [],
  "launcherVersion": ">=26.8-beta.3-fix"
}
```

Java/Kotlin 插件可选声明启动前 Mixin 配置：

```json
{
  "schemaVersion": 4,
  "type": "java",
  "entrypoint": "com.example.MyPlugin",
  "dependencies": [],
  "permissions": ["mixin"],
  "requiredPermissions": ["mixin"],
  "launcherVersion": ">=26.8-beta.3-fix",
  "mixins": ["mixins.com.example.plugin.json"]
}
```

Mixin 配置及其类必须放在插件 JAR 的资源/类路径中。所有新安装和更新都会先进入待重启状态，当前进程不会注册或执行新包；含 Mixin 的插件在启用、禁用、更新和卸载后还必须通过下一次启动重新建立 Agent 状态。

## 权限与依赖声明

schema v4 要求每个插件显式填写 `permissions`、`requiredPermissions` 和 `launcherVersion`。`permissions` 是全部能力，`requiredPermissions` 必须是其中的子集：必要权限在授权界面默认开启并锁定，用户不接受时只能取消安装、禁用或卸载插件；其余可选权限可以关闭，对应功能应通过 `PluginContext` 检查并降级。`launcherVersion` 使用与插件依赖相同的版本约束语法，开发者必须明确声明兼容的 HMCL Nex 版本范围。

可声明权限：`filesystem`、`network`、`process`、`account`、`game-launch`、`launcher-ui`、`mixin`、`clipboard`、`native-code`。schema v4 插件只要包含 `mixins`，就必须把 `mixin` 同时列入 `permissions` 和 `requiredPermissions`。

授权记录绑定插件 ID、版本和 `.npl` 的 SHA-256。首次安装时必要权限固定开启、可选权限默认关闭；每次更新都会显示一张新的完整权限授予窗口，旧版本已授予且新版本仍为可选的权限作为预选项，新增可选权限默认关闭，从可选升级为必要的权限会明确标记。同版本但摘要变化的重打包同样属于更新。用户取消窗口时不会安装或更新插件，也不会改写现有授权。

这套机制门控 HMCL 官方 SDK 能力，并支持用户在管理页动态撤权；它不是同 JVM 或操作系统级沙箱。Java/Kotlin 插件仍能直接调用 JDK、JavaFX、Mixin 或启动器内部类，因此插件作者必须遵守声明，用户也只能安装可信来源的插件。

HMCL Nex 只安装和执行 schema v4 插件。含 Mixin 的插件以必要权限作为原子启动门槛：只有全部必要权限获准，并且启动前 Agent 验证精确版本和 SHA-256 后，HMCL 才会执行构造器和生命周期。关闭可选权限不会阻断主题或插件，只会让对应 SDK 功能不可用。

依赖既兼容旧的插件 ID 字符串，也支持版本约束：

```json
"dependencies": [
  {
    "id": "dev.hmclnex.example.base",
    "version": ">=1.2.0 <2.0.0"
  }
]
```

版本约束支持 `*`、精确版本、`<`、`<=`、`>`、`>=`，多个条件以空格或逗号连接。商店会递归解析依赖，并在下载前阻止缺失、冲突或循环依赖。

所有新安装和更新都使用重启事务：HMCL 先把计划中的包下载到隔离的临时目录，逐包校验大小、SHA-256、包内 ID/版本/schema、权限和依赖，并验证安装后的完整依赖图；任意一步失败都不会改动已安装包。确认后只写入待重启计划，当前进程不注册、不构造也不执行新 artifact；下一次启动才备份旧包并一次发布整组新包。

发布前会在启动器本地目录写入 `plugin-install-transaction.json` 恢复日志。若发布过程中出现普通 I/O 错误，HMCL 会立即回滚；若进程在发布中断，下一次启动会回滚尚未提交的事务，或保留已提交的新包并清理旧备份。无法完整恢复时，HMCL 会保留日志并拒绝发现插件，避免加载新旧版本混合的依赖图。

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
6. 在完整权限窗口中逐项选择允许或拒绝；依赖插件会显示独立分组。
7. 确认安装；插件进入待重启状态，选择现在重启或稍后重启。重启前当前进程不会执行新包。

安装前可验证包结构、入口、Mixin 资源、解压大小并生成发布所需摘要：

```powershell
./tools/validate-npl.ps1 ./path/to/plugin.npl
./tools/validate-npl.ps1 -Package ./path/to/plugin.npl -StoreManifest ./manifest.json
```

提供 `-StoreManifest` 时还会核对商店条目的 ID、版本、API schema、权限、依赖、字节数和 SHA-256。

## 示例功能

示例插件都包含：

- `onLoad/onEnable/onDisable/onUnload` 生命周期。
- 在适用示例中写入插件私有持久化目录。

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
context.getPermissions();
context.getDeclaredPermissions();
context.getGrantedPermissions();
context.declaresPermission(PluginPermission.NETWORK);
context.isPermissionGranted(PluginPermission.LAUNCHER_UI);
context.requirePermission(PluginPermission.LAUNCHER_UI);
context.getPluginDependencies();
```

`getPluginDirectory()` / `getPackageDirectory()` 是只应读取的解压包目录；插件持久化文件应写入 `getDataDirectory()`，更新插件时不会被覆盖。

权限可能在插件运行期间被用户撤销。不要只在 `onLoad` 缓存一次结果；在每次受保护操作前查询或调用 `requirePermission`，并捕获 `PluginPermissionException`。尤其不要让权限拒绝从 `onLoad` 或 `onEnable` 逸出，否则整个插件生命周期会被标记为失败。

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

HMCL Nex 的权限系统会门控官方 SDK 接口，但不是 JVM 或操作系统级沙箱；Mixin 还能在类加载前修改启动器字节码。请只发布和安装可信插件，并为注入点设置明确的 `defaultRequire`，避免静默失效。
