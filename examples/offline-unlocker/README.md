# HMCL CE 离线账号解锁插件

此示例通过 Mixin 修改 HMCL CE 的离线账号限制，并演示 schema-v5 Java provider 基线包的构建、校验和
隔离回归流程。

## Schema-v5 边界

Schema v5 是以 runtime、ABI 与 platform 描述兼容性的多语言、语言中立（language-neutral）合同。本示例是当前内置 JVM
基线，不代表 schema v5 仅支持 Java：

- schemaVersion: 5
- runtime: java
- ABI: 2
- `type: java`，入口实现标准 `Plugin` 生命周期
- `mixin` 同时列入 `permissions` 与 `requiredPermissions`

HMCL CE `next` 当前只内置 `java` runtime provider。.NET、QuickJS/WASM、Python 与原生 provider 属于
schema-v5 扩展方向，但本里程碑未提供；在对应 provider 安装并注册前不能执行这些外部语言包。

本示例使用的 Mixin Agent 是现有 JVM 插件能力。Schema-v5 `hooks` 与 `patches` 是另一组声明式合同，当前
已支持的游戏启动 Hook 会被分发；其他 Hook 仍只进行解析和验证，Patch 字节码执行引擎尚未提供。本示例不依赖这些声明。

## 功能与实现

插件在 `AccountListPage` 静态初始化结束时把 `RESTRICTED` 属性设为 `false`，解除“必须先登录正版账号才能
使用离线或第三方登录”的限制。

| 项目 | 值 |
| --- | --- |
| 目标类 | `org.jackhuang.hmcl.ui.account.AccountListPage` |
| 目标方法 | `<clinit>` 静态初始化器 |
| 注入位置 | `@At("TAIL")` |
| 操作 | `RESTRICTED.set(false)` |

## 构建与校验

以下命令从 SDK 仓库根目录执行。SDK 位于 `Documents/Plugins` 时，HMCL CE sibling 仓库位于
`../../HMCL-CE`：

```powershell
$env:HMCL_JAR = (Get-ChildItem ..\..\HMCL-CE\HMCL\build\libs\HMCL-*.jar |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
..\..\HMCL-CE\gradlew.bat -p .\examples\offline-unlocker clean packageNpl
./tools/validate-npl.ps1 -Package ./examples/offline-unlocker/build/npl/dev.hmclce.offlineunlocker-v1.0.0.npl
Get-Item ./examples/offline-unlocker/build/npl/dev.hmclce.offlineunlocker-v1.0.0.npl |
    Select-Object Name, Length
Get-FileHash ./examples/offline-unlocker/build/npl/dev.hmclce.offlineunlocker-v1.0.0.npl -Algorithm SHA256
```

包的大小和 SHA-256 由每次构建结果决定，不在文档中固定。发布时必须以待上传 NPL 的实际字节重新计算。

## 安装与使用

1. 启动 HMCL CE `next`。
2. 在插件管理页安装 `build/npl/dev.hmclce.offlineunlocker-v1.0.0.npl`。
3. 接受必需的 `mixin` 权限。
4. 重启 HMCL CE；Mixin 包不会在安装它的当前进程中执行。
5. 进入账号页，确认离线登录和第三方登录入口可以使用。

Mixin 权限允许插件在类加载前修改启动器字节码。安装者应核对源码、包哈希与权限声明后再授权。

## 项目结构

```text
offline-unlocker/
├── plugin.json                          # schema-v5 Java/ABI-2 清单
├── build.gradle.kts                     # 可复现 Gradle 归档配置
├── tools/regression/                    # 隔离 RED/GREEN 启动脚本
└── src/main/
    ├── java/dev/hmclce/plugin/offlineunlocker/
    │   ├── OfflineUnlockerPlugin.java
    │   ├── MixinAccountListPage.java
    │   └── InjectionMarker.java
    └── resources/
        └── mixins.offlineunlocker.json
```

## 隔离回归测试

`tools/regression/` 会关闭限制逻辑的三条既有豁免路径：

1. 强制 `-Dhmcl.offline.auth.restricted=true`，关闭属性为 `false` 的豁免。
2. 同一值会跳过 `auto` 与中国大陆区域判断。
3. 在隔离 profile 中写入 `enableOfflineAccount: false`。

以下命令从 `examples/offline-unlocker` 目录执行。该目录到 sibling HMCL 仓库需要上移四级：

```powershell
$scripts = "tools\regression"
$npl = "build\npl\dev.hmclce.offlineunlocker-v1.0.0.npl"
$jar = (Get-ChildItem "..\..\..\..\HMCL-CE\HMCL\build\libs\HMCL-*.jar" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

# RED：受限、无插件，应当无法打开离线账号对话框。
$red = & "$scripts\New-RestrictedProfile.ps1" -Root "$env:TEMP\hmcl-reg\red"
& "$scripts\Start-RestrictedHmcl.ps1" -Profile $red -HmclJar $jar `
    -LogDir "$env:TEMP\hmcl-reg\logs" -Tag red

# GREEN：同样受限、预置插件，应当可以打开离线账号对话框。
$green = & "$scripts\New-RestrictedProfile.ps1" `
    -Root "$env:TEMP\hmcl-reg\green" -PluginNpl $npl
& "$scripts\Start-RestrictedHmcl.ps1" -Profile $green -HmclJar $jar `
    -LogDir "$env:TEMP\hmcl-reg\logs" -Tag green
```

两个 profile 通过 `-Dhmcl.home` 和 `-Dhmcl.dir` 隔离，不读取或修改 `%APPDATA%\.hmcl`。
`-PluginNpl` 会预置 NPL、权限和启用状态，省去 UI 安装步骤。

判定时必须实际点击“离线模式”并观察对话框：

| 观察项 | RED（无插件） | GREEN（有插件） |
| --- | --- | --- |
| 点击“离线模式” | 无响应 | 打开“添加离线模式账户” |
| 用户名输入框 | 无 | 有 |
| 登录与取消按钮 | 无 | 有 |

不要用无障碍树中是否存在“离线模式”节点判断。JavaFX `setDisable(true)` 不会在此处移除节点，只有点击响应
差异才是有效证据。GREEN profile 的 `enableOfflineAccount` 必须仍为 `false`，否则没有隔离出 Mixin 的效果。

## 日志

标准插件生命周期日志位于：

```text
<hmcl.dir>/plugin-storage/dev.hmclce.offlineunlocker/offline-unlocker.log
```

Mixin 注入标记位于：

```text
<hmcl.dir>/plugin-data/dev.hmclce.offlineunlocker/injection.log
```

Mixin 在 pre-main Agent 阶段执行，早于 `PluginContext` 初始化，因此注入标记与生命周期日志分开记录。
`AccountListPage` 是懒加载类，只有进入账号页后才会产生 `injection.log`。

## 兼容性

- HMCL CE：`next`，且满足 `launcherVersion >=26.8-beta.3-fix`
- Java：17+
- SDK 分支：`schema-v5` 预发布
- NPL 合同：schema 5、`java`、ABI 2
- Mixin：0.8.7

SDK `schema-v4` 仍是稳定、默认分支，HMCL CE `next` 也仍接受 schema-v4 包；本示例仅演示新的
schema-v5 基线。

## 故障排查

### 插件未生效

1. 确认插件安装在当前隔离 profile 中。
2. 确认已授予必需的 `mixin` 权限。
3. 重启 HMCL CE，再进入账号页触发目标类加载。
4. 检查 `injection.log` 是否包含 `RESTRICTED set to false`。

### 构建找不到 HMCL JAR

先构建 HMCL CE `next`，再设置绝对 `HMCL_JAR`；或者保持两个仓库位于上述 sibling 目录结构，让
`build.gradle.kts` 的 fallback 自动选择最新 `HMCL-*.jar`。

### 找不到 Mixin 或 JavaFX

- 确认 Gradle 可以访问 SpongePowered Maven 仓库并解析 `org.spongepowered:mixin:0.8.7`。
- 确认示例保留 `org.openjfx.javafxplugin` 与 JavaFX controls 模块配置。
