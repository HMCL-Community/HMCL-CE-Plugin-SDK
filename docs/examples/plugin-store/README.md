# HMCL Plugin Store - Example Repository

这是一个示例插件商店仓库，展示如何配置 HMCL 插件商店。

## 文件说明

### plugins.json

插件商店注册表，包含所有可用插件的列表。

**用途**: 
- HMCL 从此文件加载插件商店
- 包含插件的基本信息和清单 URL

**配置启动器**:
```java
// 在 HMCL 中配置自定义插件源
插件管理 → 插件商店 → 设置 → 添加自定义插件源
URL: https://raw.githubusercontent.com/PCL-Nex-Developer/HMCL-Nex-Plugin-Store/main/plugins.json
```

### manifest.json

单个插件的版本清单，包含所有历史版本。

**用途**:
- 定义插件的所有可用版本
- 提供下载链接和校验和
- 记录版本兼容性和更新说明

**位置**: 放在单个插件的仓库根目录

## 快速开始

### 1. 创建插件商店仓库

```bash
# 创建新仓库
mkdir HMCL-Nex-Plugin-Store
cd HMCL-Nex-Plugin-Store

# 复制 plugins.json 模板
cp examples/plugin-store/plugins.json .

# 编辑并添加你的插件
nano plugins.json

# 提交到 GitHub
git init
git add plugins.json
git commit -m "Initialize plugin store"
git remote add origin https://github.com/PCL-Nex-Developer/HMCL-Nex-Plugin-Store.git
git push -u origin main
```

### 2. 创建插件仓库

```bash
# 创建插件仓库
mkdir my-plugin
cd my-plugin

# 添加 manifest.json
cp examples/plugin-store/manifest.json .

# 编辑版本信息
nano manifest.json

# 开发插件...
# 打包为 .npl 文件
# 创建 GitHub Release
# 更新 manifest.json
```

### 3. 使用插件商店

在 HMCL 中：
1. 打开 **设置** → **插件商店**
2. 点击 **设置** → **添加自定义插件源**
3. 输入: `https://raw.githubusercontent.com/PCL-Nex-Developer/HMCL-Nex-Plugin-Store/main/plugins.json`
4. 点击 **刷新**
5. 浏览并安装插件

## 文件结构

```
HMCL-Nex-Plugin-Store/           # 插件商店主仓库
├── README.md
└── plugins.json                 # 插件列表

my-plugin/                       # 单个插件仓库
├── README.md
├── manifest.json                # 版本清单
├── plugin.json                  # 插件元数据
├── src/                         # 源代码
└── releases/                    # .npl 文件 (通过 GitHub Releases)
```

## 更多信息

- [插件商店配置指南](../../PLUGIN_STORE_SETUP.md)
- [插件开发指南](../../PLUGIN_DEVELOPMENT.md)
- [快速入门](../../PLUGIN_QUICKSTART.md)

## 默认插件商店

默认插件商店：https://github.com/PCL-Nex-Developer/HMCL-Nex-Plugin-Store

## 贡献

欢迎提交你的插件到 HMCL Nex 插件商店！

1. Fork 此仓库
2. 在 `plugins.json` 添加你的插件
3. 创建 Pull Request
4. 等待审核

## 许可证

遵循 HMCL 的 GPL-3.0 许可证。
