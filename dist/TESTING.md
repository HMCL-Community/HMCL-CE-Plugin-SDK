# 示例插件测试包

本目录包含四个 HMCL Nex 示例插件，包括真实启动验证过的 Java Mixin 示例。

## 启动器

使用相邻 HMCL 工程生成的启动器：

```text
../HMCL-Nex/HMCL/build/libs/HMCL-<version>.jar
```

## 安装

1. 启动 HMCL Nex。
2. 点击主界面的“插件”。
3. 选择“管理插件”。
4. 点击“安装插件”，选择本目录中的一个 `.npl` 文件。
5. 在权限窗口中检查必要权限固定开启；首次安装的可选权限默认关闭，可按需开启。
6. 确认安装后先检查插件显示为待重启，且当前进程没有出现新页面或生命周期输出。
7. 选择“现在重启”。
8. 对其他插件重复以上操作。

## 预期行为

### Java

- 授予 `launcher-ui` 后注册 Java HelloWorld 页面；拒绝时插件保持启用但不注册页面。
- 页面按钮可以显示 HMCL 对话框、修改窗口标题和写入数据文件。
- 运行中撤销 `launcher-ui` 后侧栏入口立即移除，权限异常不会使插件生命周期失败。

### Kotlin

- 授予 `launcher-ui` 后注册 Kotlin HelloWorld 页面；拒绝时插件保持启用但不注册页面。
- 页面按钮可以显示 HMCL 对话框、修改窗口标题和写入数据文件。
- 插件包已包含 Kotlin 标准库。

### JavaScript

- 授予 `launcher-ui` 后在“插件”菜单中注册 JavaScript HelloWorld 页面；拒绝时生命周期仍正常完成。
- 页面是 HMCL 根据 `hmcl-ui-v1` 控件树创建的真实 JavaFX 页面。
- 输入名称并点击 “Say hello” 后，Node.js 事件处理器会更新页面状态文本。
- 点击 “Show dialog” 后，Node.js 事件处理器会请求 HMCL 显示原生对话框。
- 只使用 HMCL 自动下载的 Node.js v24.18.0，不读取系统安装的 JavaScript 环境。
- 日志和 `data.txt` 写入插件私有持久化目录，因此不申请 `filesystem`。

### Java Mixin

- `mixin` 显示为固定开启的必要权限；确认安装后保持待重启，当前进程不输出任何 Mixin 或生命周期标记。
- 启动控制台先输出 `Launcher.main injection applied`，之后生命周期输出 `injected=true`。
- 禁用或卸载后需要再次重启，已经注入的字节码不会在运行中撤销。

## 完整性校验

SHA-256 值见 `SHA256SUMS.txt`。

更新测试还应确认每次更新都会显示新的完整权限窗口：必要权限固定开启，仍声明的旧可选授权作为预选，新增可选权限默认关闭，可选权限升级为必要时明确标记；取消后旧包和旧授权保持不变。
