# 插件开发指南

## 支持的运行时

HMCL CE 支持 JVM 插件和由独立 .NET Host 执行的 C# Companion 扩展：

| 类型 | 值 | 入口要求 |
| --- | --- | --- |
| Java | `java` | 实现 `Plugin` 的 Java 类 |
| Kotlin | `kotlin` | 实现 `Plugin` 的 Kotlin 类 |
| C# Companion | `csharp` | `companion/extension.json`，由 .NET Host 加载 |

`javascript` 不是有效插件类型。HMCL CE 不下载 Node.js、不读取系统 Node.js，也不提供 JavaScript UI 协议。

## 包结构

```text
plugin.npl
├── plugin.json
└── libs/
    └── plugin.jar
```

每个 `.npl` 必须采用 schema v4，且 `entrypoint` 对应的 `.class` 必须在包根目录或一个 `libs/*.jar` 中。

C# Companion 包不包含 JVM 生命周期类。根清单的 `entrypoint` 必须是 `companion/extension.json`，且该嵌套
清单的 ID 与版本必须与根 `plugin.json` 一致。DLL、`.deps.json` 与 `extension.json` 均放在 `companion/` 下。

## 清单

```json
{
  "schemaVersion": 4,
  "id": "com.example.hmclce.plugin",
  "name": "HMCL CE Plugin",
  "version": "1.0.0",
  "type": "java",
  "entrypoint": "com.example.hmclce.PluginMain",
  "dependencies": [],
  "permissions": ["launcher-ui"],
  "requiredPermissions": [],
  "launcherVersion": ">=26.8"
}
```

`permissions` 是完整声明，`requiredPermissions` 必须是其中的子集。启动器实际授予的能力绑定插件 ID、版本和包 SHA-256；更新包需要重新确认授权。

## 生命周期

```java
public final class PluginMain implements Plugin {
    private PluginContext context;

    @Override
    public void onLoad(PluginContext context) {
        this.context = context;
    }

    @Override
    public void onEnable() {
        if (context.isPermissionGranted(PluginPermission.LAUNCHER_UI)) {
            context.registerSidebarItem("Plugin", () -> Controllers.dialog("Enabled", "Plugin"));
        }
    }
}
```

不要只在 `onLoad` 缓存授权状态。用户可以在运行期撤销权限，调用受保护 API 时应检查权限并捕获 `PluginPermissionException`。

## Mixin

Mixin 仅适用于 Java/Kotlin 插件。把配置文件放入插件 JAR，声明 `mixins`，并把 `mixin` 同时放入 `permissions` 和 `requiredPermissions`。Mixin 变更需要重启，因为启动器会在类加载前由 Agent 完成验证与注入。

## 校验与发布

```powershell
./tools/validate-npl.ps1 -Package ./build/npl/plugin.npl
Get-FileHash ./build/npl/plugin.npl -Algorithm SHA256
```

发布前使用对应示例在本地 HMCL CE 构建上测试包的安装、授权、重启、启用和卸载流程。C# Companion 包可使用
`HMCL-CE-Companion/samples/HMCL.CE.Companion.RuntimeProbe/pack-npl.ps1` 生成参考结构。

C# 扩展的 `Sidebar`、`Settings`、`Tools` 页面注册与控件表见 [C# 原生页面](CSHARP_NATIVE_PAGES.md)。

## 发布与认证

第三方仓库使用全小写 GitHub Topic `hmclce`，默认分支发布 schema v2 `manifest.json`。社区版本可以保持未认证；需要“官方认证”标签的版本必须同时通过仓库复核和当前 NPL 的独立审批。

认证发布使用 SDK 的 GitHub Actions 模板：

- 工作流只需要 `contents: write` 权限。
- Repository Variable `HMCLCE_PLUGIN_RELEASE_MODE` 设为 `certified`。
- 社区发布不需要任何 Repository Variable 或 Secret。
- 不创建开发者签名私钥、长期 API Key 或 `HMCLCE_PLUGIN_CERTIFICATE`。

审批服务会从草稿 GitHub Release 自行下载资产。仓库最多每七天复核一次，每个新 NPL 都重新校验和签发证明。完整字段和失败规则见 [插件发布与认证要求](PLUGIN_STORE_SETUP.md)。
