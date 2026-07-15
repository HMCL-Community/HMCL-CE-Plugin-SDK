# 示例插件测试包

本目录包含 2026-07-14 干净构建的三个 HMCL Nex 示例插件。

## 启动器

使用相邻 HMCL 工程生成的启动器：

```text
../HMCL/HMCL/build/libs/HMCL-3.17.SNAPSHOT.jar
```

## 安装

1. 启动 HMCL Nex。
2. 点击主界面的“插件”。
3. 选择“管理插件”。
4. 点击“安装插件”，选择本目录中的一个 `.npl` 文件。
5. 阅读并确认红色风险警告。
6. 安装完成后选择“现在重启”。
7. 对另外两个插件重复以上操作。

## 预期行为

### Java

- 启用时显示提示框。
- 自动打开 Java HelloWorld 页面。
- 页面按钮可以显示 HMCL 对话框、修改窗口标题和写入数据文件。

### Kotlin

- 启用时显示提示框。
- 自动打开 Kotlin HelloWorld 页面。
- 页面按钮可以显示 HMCL 对话框、修改窗口标题和写入数据文件。
- 插件包已包含 Kotlin 标准库。

### JavaScript

- 启用后在“插件”菜单中注册 JavaScript HelloWorld 页面。
- 页面是 HMCL 根据 `hmcl-ui-v1` 控件树创建的真实 JavaFX 页面。
- 输入名称并点击 “Say hello” 后，Node.js 事件处理器会更新页面状态文本。
- 点击 “Show dialog” 后，Node.js 事件处理器会请求 HMCL 显示原生对话框。
- 只使用 HMCL 自动下载的 Node.js v24.18.0，不读取系统安装的 JavaScript 环境。

## 完整性校验

SHA-256 值见 `SHA256SUMS.txt`。
