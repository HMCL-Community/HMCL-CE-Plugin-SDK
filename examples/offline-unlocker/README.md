# HMCL Nex 离线账号解锁插件

## 功能说明

此插件移除 HMCL Nex 中"必须先登录正版账号才能使用离线/第三方登录"的限制。

**技术实现**：通过 Mixin 字节码注入，在 AccountListPage 静态初始化时强制设置 RESTRICTED 属性为 false。

## 文件位置

**插件包**：`build/npl/dev.hmclnex.offlineunlocker-v1.0.0.npl`

**包信息**:
- 大小: 3303 字节
- SHA-256: ce79ebd95e10d49339a31c7fa8a9d16148c322a51dc02aa2d8f602ba8bdcb86e
- SDK 验证: ✅ 通过

## 安装步骤

1. 启动 HMCL Nex
2. 左侧菜单点击"插件"
3. 点击"管理插件"
4. 点击"安装插件"
5. 选择上述 .npl 文件
6. 在权限对话框中接受 **mixin** 权限（必需权限）
7. 点击"现在重启"

## 使用方法

插件安装并重启后：

1. 进入"账号"页面
2. 离线登录按钮和第三方登录选项现在都可以点击（不再灰色禁用）
3. 直接创建离线账号，无需先登录正版

## 技术细节

### SDK v4 合规性

- ✅ schemaVersion: 4
- ✅ 明确声明 mixin 权限（permissions + requiredPermissions）
- ✅ 声明 launcherVersion 约束
- ✅ 完整的插件生命周期实现

### Mixin 注入点

**目标类**: `org.jackhuang.hmcl.ui.account.AccountListPage`  
**注入方法**: `<clinit>` (静态初始化器)  
**注入位置**: `@At("TAIL")` (静态块末尾)  
**操作**: `RESTRICTED.set(false)`

### 项目结构

```
offline-unlocker/
├── plugin.json                          # SDK v4 清单
├── build.gradle.kts                     # Gradle 构建脚本
└── src/main/
    ├── java/dev/hmclnex/plugin/offlineunlocker/
    │   ├── OfflineUnlockerPlugin.java   # 插件主类
    │   └── MixinAccountListPage.java    # Mixin 注入类
    └── resources/
        └── mixins.offlineunlocker.json  # Mixin 配置
```

## 重新构建

如需修改并重新构建：

```powershell
cd ..\HMCL-Nex
.\gradlew.bat -p ..\HMCL-Nex-Plugin-SDK\examples\offline-unlocker clean packageNpl
```

以上命令假设 HMCL-Nex 与本 SDK 仓库检出在同一父目录；也可以通过
`HMCL_JAR` 环境变量指定已构建的 HMCL JAR。

输出位置: `build/npl/dev.hmclnex.offlineunlocker-v1.0.0.npl`

## 回归测试

`tools/regression/` 下提供受限环境的构造脚本，用于做 RED/GREEN 对照验证。

### 为什么需要它

`AccountListPage` 的闸门有三条豁免路径，任意一条成立就会自动解锁：

1. `-Dhmcl.offline.auth.restricted=false`
2. 该属性为 `auto` **且** `LocaleUtils.IS_CHINA_MAINLAND` 为真
3. 持久化配置 `enableOfflineAccount` 为 `true`

若在已解锁的环境里测试，离线登录本来就是通的，验证结果没有意义
（本项目开发过程中确实先踩了这个坑）。脚本会把三条路径全部关闭：
强制属性为 `true` 使 (1)(2) 失效（`true` 短路掉 `auto` 分支，
机器所在时区/区域完全不参与），并在隔离 profile 中写入
`enableOfflineAccount: false` 关闭 (3)。

### 用法

```powershell
$scripts = "tools\regression"
$npl     = "build\npl\dev.hmclnex.offlineunlocker-v1.0.0.npl"
$jar     = "..\..\..\HMCL-Nex\HMCL\build\libs\HMCL-<version>.jar"

# RED：受限、无插件 —— 应当无法离线登录
$red = & "$scripts\New-RestrictedProfile.ps1" -Root "$env:TEMP\hmcl-reg\red"
& "$scripts\Start-RestrictedHmcl.ps1" -Profile $red -HmclJar $jar -LogDir "$env:TEMP\hmcl-reg\logs" -Tag red

# GREEN：同样受限、预置插件 —— 应当可以离线登录
$green = & "$scripts\New-RestrictedProfile.ps1" -Root "$env:TEMP\hmcl-reg\green" -PluginNpl $npl
& "$scripts\Start-RestrictedHmcl.ps1" -Profile $green -HmclJar $jar -LogDir "$env:TEMP\hmcl-reg\logs" -Tag green
```

两个 profile 通过 `-Dhmcl.home` / `-Dhmcl.dir` 完全隔离，不会读写
`%APPDATA%\.hmcl`。`-PluginNpl` 会直接预置成已安装已授权状态
（`plugins/<id>.npl` + `plugin-permissions.json` + `plugin-states.json`），
省去 UI 点击安装。

### 判定方式

进入账户页点击"离线模式"，**看是否弹出对话框**：

| | RED（无插件） | GREEN（有插件） |
|---|---|---|
| 点击"离线模式" | 无反应 | 弹出"添加离线模式账户" |
| 用户名输入框 | 无 | 有 |
| 登录/取消按钮 | 无 | 有 |

> 不要用无障碍树里"离线模式"节点是否存在来判断。JavaFX 的
> `setDisable(true)` 在这里不会反映为无障碍属性，禁用状态下该节点依然列出。
> **只有点击响应的差异才是有效证据。**

### 已验证结果

| 场景 | 结果 | 证据 |
|---|---|---|
| S2 构建打包 | PASS | Gradle exit 0；validate-npl 通过；SHA-256 一致 |
| S1-RED 复现限制 | PASS | 受限 profile 中点击两次无反应，右侧面板空白 |
| S1-GREEN 解除限制 | PASS | 同配置下弹出对话框，焦点落到输入框 |
| S1-GREEN 端到端 | PASS | 创建 `green_arm_user`，写入 `user-accounts.json` |
| 插件加载 | PASS | `Loaded plugin: Offline Account Unlocker v1.0.0` → `Enabled` |
| 环境隔离 | PASS | 真实 profile 时间戳全程未变 |

其中最关键的一条：GREEN 臂创建账户后，隔离 profile 的
`enableOfflineAccount` **仍为 `false`**。三条豁免路径全部关闭而闸门开启，
只可能来自 Mixin 对 `RESTRICTED` 的改写。

## 日志位置

插件生命周期日志（由 `PluginContext.getDataDirectory()` 决定）：

```
<hmcl.dir>/plugin-storage/dev.hmclnex.offlineunlocker/offline-unlocker.log
```

默认 `<hmcl.dir>` 为启动目录下的 `.hmcl`。预期内容：

```
[OfflineUnlocker] Plugin loaded on HMCL 26.8-beta.SNAPSHOT
[OfflineUnlocker] Mixin will unlock offline account restrictions during static initialization
[OfflineUnlocker] Plugin enabled
```

Mixin 注入标记单独记录在：

```
<hmcl.dir>/plugin-data/dev.hmclnex.offlineunlocker/injection.log
```

```
[mixin] RESTRICTED set to false
```

两者分开是有原因的：Mixin 在 pre-main agent 阶段执行，早于插件生命周期，
此时 `PluginContext` 尚不存在、`System.out` 也还没接入启动器日志管线，
`println` 不会出现在启动器日志里。

`injection.log` 只在 `AccountListPage` 首次被加载时产生 —— 该类是懒加载的，
需要先进入账户页。启动后立即查看该文件不存在属于正常现象。

## 兼容性

- **HMCL Nex 版本**: >= 26.8-beta.3-fix
- **Java 版本**: 17+
- **SDK 版本**: v4
- **Mixin 版本**: 0.8.7

## 安全说明

此插件使用 **mixin** 权限修改 HMCL 启动器的内部类。该权限在安装时会明确提示用户，属于高权限操作。

**用户需明确理解**：
- Mixin 可以在类加载前修改字节码
- 此插件仅移除账号限制逻辑，不涉及其他功能
- 源代码完全透明，位于本地目录

## 故障排查

### 插件未生效（离线按钮仍然灰色）

1. 检查插件是否正确安装：管理插件 → 确认"Offline Account Unlocker"存在
2. 确认已重启 HMCL（mixin 插件必须重启才能生效）
3. 检查日志是否包含"RESTRICTED set to false"
4. 确认 mixin 权限已授予（插件详情页查看）

### 构建失败

**错误**: `Could not find org.spongepowered:mixin:0.8.7`  
**解决**: 确保 build.gradle.kts 包含 SpongePowered Maven 仓库

**错误**: `package javafx.beans.property does not exist`  
**解决**: 确保 build.gradle.kts 包含 JavaFX plugin

## 作者

HMCL Community

## 协议

本插件遵循 HMCL Nex 插件开发规范，仅供学习交流使用。
