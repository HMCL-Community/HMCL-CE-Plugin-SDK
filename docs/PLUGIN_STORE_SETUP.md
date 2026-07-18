# HMCL 插件商店 - GitHub 仓库配置指南

本指南说明如何设置 GitHub 仓库以支持 HMCL 插件商店。

## 插件商店仓库结构

### 主仓库 (插件列表)

使用 PCL-Nex-Developer 组织的 `HMCL-Nex-Plugin-Store` 仓库作为默认插件商店注册表。

**plugins.json** (根目录):

```json
{
  "schemaVersion": 1,
  "name": "HMCL Plugin Market Registry",
  "description": "HMCL Nex 插件市场列表",
  "homepageUrl": "https://github.com/PCL-Nex-Developer/HMCL-Nex-Plugin-Store",
  "plugins": [
    {
      "id": "com.example.hello",
      "name": "Hello World Plugin",
      "author": "HMCL Team",
      "description": "一个简单的示例插件",
      "manifestUrl": "https://raw.githubusercontent.com/PCL-Nex-Developer/hello-plugin/main/manifest.json",
      "repository": "https://github.com/PCL-Nex-Developer/hello-plugin",
      "capabilities": ["lifecycle", "mixin"]
    },
    {
      "id": "com.example.another",
      "name": "Another Plugin",
      "author": "Community",
      "description": "另一个插件",
      "manifestUrl": "https://raw.githubusercontent.com/developer/another-plugin/main/manifest.json",
      "repository": "https://github.com/developer/another-plugin"
    }
  ]
}
```

### 字段说明

- `name`: 插件商店名称
- `description`: 插件商店描述
- `homepageUrl`: 主页 URL
- `plugins`: 插件列表数组
  - `id`: 插件唯一标识符（与 plugin.json 中的 id 匹配）
  - `name`: 插件显示名称
  - `author`: 作者名称
  - `description`: 插件简短描述
  - `manifestUrl`: 插件清单文件的原始 URL
  - `repository`: 插件仓库 URL
  - `capabilities`: 可检索能力，例如 `lifecycle`、`javafx`、`mixin`、`javascript`

---

## 单个插件仓库结构

每个插件应该有自己的 GitHub 仓库，包含以下文件：

```
plugin-repository/
├── manifest.json          # 版本清单（必需）
├── plugin.json            # 插件元数据（可选，用于额外信息）
├── README.md              # 说明文档
└── releases/              # 发布的 .npl 文件（通过 GitHub Releases）
```

### manifest.json

定义插件的所有版本和下载信息：

```json
{
  "schemaVersion": 1,
  "id": "com.example.hello",
  "versions": [
    {
      "version": "1.0.0",
      "packageUrl": "https://github.com/PCL-Nex-Developer/hello-plugin/releases/download/v1.0.0/com.example.hello-v1.0.0.npl",
      "sha256": "64 位十六进制 SHA-256",
      "minLauncherVersion": "3.0.0",
      "requiredJavaVersion": "17",
      "pluginApiVersion": 2,
      "requiresRestart": true,
      "channel": "stable",
      "size": 102400,
      "releaseNotes": "首次发布",
      "releaseDate": "2026-07-14"
    },
    {
      "version": "0.9.0",
      "packageUrl": "https://github.com/PCL-Nex-Developer/hello-plugin/releases/download/v0.9.0/com.example.hello-v0.9.0.npl",
      "sha256": "64 位十六进制 SHA-256",
      "minLauncherVersion": "3.0.0",
      "requiredJavaVersion": "17",
      "pluginApiVersion": 2,
      "requiresRestart": true,
      "channel": "stable",
      "size": 98304,
      "releaseNotes": "https://github.com/PCL-Nex-Developer/hello-plugin/releases/tag/v0.9.0",
      "releaseDate": "2026-07-01"
    }
  ]
}
```

### 字段说明

- `schemaVersion`: 当前固定为 `1`
- `id`: 必须与主注册表条目以及 `.npl/plugin.json` 完全一致
- `versions`: 版本列表；HMCL 会按语义版本比较选择最新版本，不依赖数组顺序
  - `version`: 版本号（语义化版本）
  - `packageUrl`: .npl 文件的直接下载链接
  - `sha256`: 64 位十六进制 SHA-256（必需）
  - `minLauncherVersion`: 最低启动器版本要求
  - `requiredJavaVersion`: 最低 Java feature 版本
  - `pluginApiVersion`: `.npl/plugin.json` 的 `schemaVersion`，当前推荐 `2`
  - `requiresRestart`: Mixin 插件或无法热替换的版本填 `true`
  - `channel`: `stable`、`beta` 或 `nightly`
  - `size`: `.npl` 精确字节数（必需用于下载上限校验）
  - `releaseNotes`: 更新说明（文本或 URL）
  - `releaseDate`: 发布日期（YYYY-MM-DD）

### plugin.json (可选)

额外的插件元数据，可用于插件开发时参考：

```json
{
  "schemaVersion": 2,
  "id": "com.example.hello",
  "name": "Hello World Plugin",
  "version": "1.0.0",
  "author": "HMCL Team",
  "description": "一个简单的示例插件",
  "type": "java",
  "entrypoint": "com.example.hello.HelloPlugin",
  "mixins": ["mixins.com.example.hello.json"]
}
```

---

## 发布流程

### 1. 准备插件文件

构建你的插件并打包为 `.npl` 文件：

```bash
# 示例：打包 Java 插件
cd my-plugin
zip -r com.example.hello-v1.0.0.npl plugin.json classes/ libs/
```

### 2. 计算 SHA-256

```bash
# Linux/macOS
sha256sum com.example.hello-v1.0.0.npl

# Windows (PowerShell)
Get-FileHash com.example.hello-v1.0.0.npl -Algorithm SHA256
```

### 3. 创建 GitHub Release

1. 进入插件仓库
2. 点击 "Releases" → "Create a new release"
3. 标签：`v1.0.0`
4. 标题：`Version 1.0.0`
5. 描述：更新说明
6. 上传 `.npl` 文件
7. 发布

### 4. 获取下载链接

发布后，右键点击 `.npl` 文件 → "复制链接地址"

格式：`https://github.com/用户名/仓库名/releases/download/标签/文件名.npl`

### 5. 更新 manifest.json

在插件仓库中更新 `manifest.json`：

```json
{
  "schemaVersion": 1,
  "id": "com.example.hello",
  "versions": [
    {
      "version": "1.0.0",
      "packageUrl": "刚才复制的链接",
      "sha256": "刚才计算的哈希值",
      "minLauncherVersion": "3.0.0",
      "requiredJavaVersion": "17",
      "pluginApiVersion": 2,
      "requiresRestart": false,
      "channel": "stable",
      "size": 102400,
      "releaseNotes": "更新说明",
      "releaseDate": "2026-07-14"
    }
  ]
}
```

提交并推送到 GitHub。

### 6. 更新插件商店列表

如果是新插件，需要在主仓库的 `plugins.json` 中添加条目：

```json
{
  "id": "com.example.hello",
  "name": "Hello World Plugin",
  "author": "你的名字",
  "description": "插件描述",
  "manifestUrl": "https://raw.githubusercontent.com/你的用户名/插件仓库/main/manifest.json",
  "repository": "https://github.com/你的用户名/插件仓库"
}
```

---

## 最佳实践

### 1. 使用安全原始内容链接

manifest.json 的 URL 应使用 GitHub raw 链接：

```
https://raw.githubusercontent.com/用户名/仓库名/分支/manifest.json
```

远程注册表、清单和插件包必须使用 HTTPS；只有本地开发的回环地址允许 HTTP。

### 2. 版本管理

- 使用语义化版本 (Semantic Versioning)
- 版本列表从新到旧排序
- 保留旧版本以支持降级

### 3. 安全性

- 始终提供 SHA-256 校验和
- 使用 HTTPS 链接
- 定期审查依赖

### 4. 文档

- 提供详细的 README.md
- 记录每个版本的更新内容
- 说明安装和使用方法

### 5. 兼容性

- 明确指定最低启动器版本
- 测试多个 HMCL 版本
- 提供兼容性矩阵

---

## 示例仓库

### 插件商店主仓库

```
HMCL-Nex-Plugin-Store/
├── README.md
└── plugins.json
```

GitHub: https://github.com/PCL-Nex-Developer/HMCL-Nex-Plugin-Store

### 单个插件仓库

```
hello-plugin/
├── README.md
├── manifest.json
├── plugin.json
├── src/
└── .github/
    └── workflows/
        └── release.yml  # 自动化发布
```

---

## 自动化发布 (可选)

使用 GitHub Actions 自动化插件发布：

**.github/workflows/release.yml**:

```yaml
name: Release Plugin

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Build Plugin
        run: |
          # 编译和打包插件
          zip -r plugin.npl plugin.json classes/ libs/
      
      - name: Calculate SHA256
        run: |
          sha256sum plugin.npl > checksum.txt
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            plugin.npl
            checksum.txt
```

---

## 提交到 HMCL Nex 插件商店

1. Fork `PCL-Nex-Developer/HMCL-Nex-Plugin-Store` 仓库
2. 在 `plugins.json` 中添加你的插件
3. 创建 Pull Request
4. 等待审核

审核标准：
- 插件可正常工作
- 代码安全可靠
- 文档完整清晰
- 遵循开发规范

---

## 常见问题

### Q: 如何更新插件？

**A:** 创建新的 GitHub Release，更新 manifest.json，插件商店会自动显示新版本。

### Q: 支持多个下载源吗？

**A:** 可以。在 `packageUrl` 中使用 CDN 或镜像链接。

### Q: 可以托管在 Gitee 吗？

**A:** 可以，只要能提供公开的原始文件访问。

### Q: 如何撤回版本？

**A:** 从 manifest.json 中删除对应版本，或删除 GitHub Release。

---

## 技术支持

- HMCL 文档: https://docs.hmcl.net/
- 插件商店: https://github.com/PCL-Nex-Developer/HMCL-Nex-Plugin-Store
- 插件开发指南: `PLUGIN_DEVELOPMENT.md`
