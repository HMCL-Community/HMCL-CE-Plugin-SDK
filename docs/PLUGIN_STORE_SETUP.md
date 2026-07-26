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
  "schemaVersion": 2,
  "id": "com.example.hello",
  "readmeUrl": "https://raw.githubusercontent.com/PCL-Nex-Developer/hello-plugin/main/README.md",
  "versions": [
    {
      "version": "1.0.0",
      "packageUrl": "https://github.com/PCL-Nex-Developer/hello-plugin/releases/download/v1.0.0/com.example.hello-v1.0.0.npl",
      "sha256": "64 位十六进制 SHA-256",
      "launcherVersion": ">=26.8-beta.3-fix",
      "requiredJavaVersion": "17",
      "pluginApiVersion": 4,
      "permissions": ["filesystem", "launcher-ui"],
      "requiredPermissions": ["launcher-ui"],
      "dependencies": [],
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
      "launcherVersion": ">=26.8-beta.3-fix",
      "requiredJavaVersion": "17",
      "pluginApiVersion": 4,
      "permissions": ["filesystem", "launcher-ui"],
      "requiredPermissions": ["launcher-ui"],
      "dependencies": [],
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

- `schemaVersion`: 当前版本为 `2`；HMCL 仍可读取旧的 v1 清单
- `id`: 必须与主注册表条目以及 `.npl/plugin.json` 完全一致
- `readmeUrl`: 仓库 README 原始文本 URL，商店详情页会在受限大小内读取并展示；外部图片、媒体和嵌入资源不会自动加载，链接仅在用户点击后打开
- `versions`: 版本列表；HMCL 会按语义版本比较选择最新版本，不依赖数组顺序
  - `version`: 版本号（语义化版本）
  - `packageUrl`: .npl 文件的直接下载链接
  - `sha256`: 64 位十六进制 SHA-256（必需）
  - `launcherVersion`: API v4 必填的 HMCL Nex 版本约束；旧 API 版本继续使用 `minLauncherVersion`
  - `requiredJavaVersion`: 最低 Java feature 版本
  - `pluginApiVersion`: `.npl/plugin.json` 的 `schemaVersion`；新版本必须为 `4`，历史 v1-v3 元数据只用于旧包展示和升级
  - `permissions`: API v4 必填并与下载包内 `plugin.json` 完全一致
  - `requiredPermissions`: API v4 必填的必要权限子集，并与下载包完全一致；旧 API 版本必须省略
  - `dependencies`: 该版本的依赖 ID 与版本约束；必须与下载包内声明一致
  - `requiresRestart`: Mixin 插件或自身状态无法跨进程沿用的版本填 `true`；HMCL 仍会把所有新安装和更新统一暂存到下次启动
  - `channel`: `stable`、`beta` 或 `nightly`
  - `size`: `.npl` 精确字节数（必需用于下载上限校验）
  - `releaseNotes`: 更新说明（文本或 URL）
  - `releaseDate`: 发布日期（YYYY-MM-DD）

### 多包安装与崩溃恢复

安装带有插件依赖的版本时，HMCL 会先求解完整版本计划，并把所有需要安装或更新的 `.npl` 下载到隔离的临时目录。每个包都会在接触已安装文件前完成兼容性、声明大小、SHA-256、包内 ID/版本/schema、权限和依赖交叉校验；随后还会验证计划完成后的完整依赖图，包括已安装插件对待更新依赖的反向约束。只要任意下载或校验失败，已安装插件目录就保持不变。

求解完成后，新的完整授权窗口会为所有需要安装或更新的插件（包括依赖）分别显示权限分组。首次安装默认全部关闭；每次更新都会出现该窗口，旧授权与新声明的交集仅预选，新增权限默认关闭。同版本包的 SHA-256 变化也视为更新，用户必须再次确认，确认结果才会绑定到新摘要。用户取消授权窗口会取消整个安装计划，现有包和授权都不改变；计划中复用的现有依赖不会显示或改写授权。

所有新安装和更新都会作为重启事务暂存，当前进程不会注册或运行新包。HMCL 在下一次启动时复制并再次校验全部暂存包，再备份相关旧包并发布整组新包；多包依赖计划仍作为不可拆分的一组处理。普通发布错误会删除已发布的新目标并恢复旧包。

为处理发布期间的进程中断，HMCL 在移动任何已安装包前写入 `.hmcl/plugin-install-transaction.json`。下次启动遇到 `prepared` 事务时会删除部分发布的新目标并恢复旧备份；遇到 `committed` 事务时会保留整组新目标，只清理旧备份和暂存文件。若日志无效或任何恢复步骤未完成，日志会继续保留，插件发现也会停止，直到恢复能够完整完成，从而不会加载新旧包混合的依赖图。

### plugin.json（NPL 内必需）

每个下载包根目录都必须包含插件清单；商店会把这些字段与版本元数据交叉校验：

```json
{
  "schemaVersion": 4,
  "id": "com.example.hello",
  "name": "Hello World Plugin",
  "version": "1.0.0",
  "author": "HMCL Team",
  "description": "一个简单的示例插件",
  "type": "java",
  "entrypoint": "com.example.hello.HelloPlugin",
  "dependencies": [],
  "permissions": ["launcher-ui", "mixin"],
  "requiredPermissions": ["launcher-ui", "mixin"],
  "launcherVersion": ">=26.8-beta.3-fix",
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
jar --create --file com.example.hello-v1.0.0.npl plugin.json libs
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
  "schemaVersion": 2,
  "id": "com.example.hello",
  "readmeUrl": "https://raw.githubusercontent.com/owner/repo/main/README.md",
  "versions": [
    {
      "version": "1.0.0",
      "packageUrl": "刚才复制的链接",
      "sha256": "刚才计算的哈希值",
      "launcherVersion": ">=26.8-beta.3-fix",
      "requiredJavaVersion": "17",
      "pluginApiVersion": 4,
      "permissions": ["launcher-ui"],
      "requiredPermissions": [],
      "dependencies": [],
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
      - uses: actions/checkout@v4
      
      - name: Build Plugin
        run: |
          # 编译和打包插件
          jar --create --file plugin.npl plugin.json libs/
      
      - name: Calculate SHA256
        run: |
          sha256sum plugin.npl > checksum.txt
      
      - name: Create Release
        uses: softprops/action-gh-release@v2
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
