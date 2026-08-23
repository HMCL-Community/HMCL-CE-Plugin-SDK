# HMCL CE 插件发布与商店收录

本分支的发布模板生成面向 HMCL CE `next` 的 schema-v5 包。Schema v5 是语言中立的 runtime、ABI 与
platform 合同；当前模板使用内置 `java` provider 和 ABI 2。SDK `schema-v4` 仍是稳定、默认分支，`next`
也仍接受 schema-v4 包。

HMCL CE 通过两类来源发现插件，都会显示在启动器的插件商店中：

- **GitHub Topic 发现（社区模式，默认）**：任何公开仓库添加全小写 Topic `hmclce`，并在默认分支根目录提供 `manifest.json`（Store schema v2），启动器即可自动发现其中的插件版本。不需要审批 API、开发者证书或人工复核。
- **官方源（已认证标识）**：由社区维护的 `HMCL-CE-Plugin-Store` 仓库以 `plugins.json` 索引收录经审核的插件。收录只增加来源标签，不是安装前提。

## 社区发布清单

1. 公开 GitHub 仓库，添加全小写 Topic：`hmclce`。
2. 默认分支根目录放置 `manifest.json`（Store schema v2，模板见 `store/manifest.template.json`）。
3. 每个 `versions[]` 条目对应一个 Release：tag 使用 `v<SemVer>`，附件上传对应 `.npl`；`packageUrl`、`sha256` 与 `size` 必须绑定实际上传字节。
4. Schema-v5 版本使用 `pluginApiVersion: 5`，并让 `launcherVersion`、`permissions`、`requiredPermissions`、`dependencies`、`runtime`、`abi` 与规范化 `platforms` 精确匹配包内 `plugin.json`。

模板中的兼容性字段如下：

```json
{
  "pluginApiVersion": 5,
  "runtime": "java",
  "abi": 2,
  "platforms": []
}
```

空 `platforms` 表示不限平台。当前 Store 合同不提供目标制品矩阵或按平台选择多个下载包；一个版本条目仍然
对应一个 `packageUrl`。Schema-v4 版本不能声明 runtime、ABI 或 platforms，启动器会将其解释为 Java、ABI 1、
无平台限制。

启动器在安装前校验仓库清单、插件 ID、版本、下载地址、SHA-256、依赖、权限以及 runtime/ABI/platform
合同，并与下载 NPL 再次核对。不匹配的版本不会进入加载流程。

## 外部运行时边界

.NET、QuickJS/WASM、Python 与原生 provider 属于 schema-v5 体系，但当前里程碑未提供这些 provider。
只有 runtime provider 已注册且支持声明 ABI 时，对应包才可能执行；发布清单本身不会安装 provider。
当前示例和模板仅演示 `runtime: "java"`。

Hook/Patch 字段也只在包清单中完成合同校验。当前 HMCL CE `next` 不分发 Hook，也不执行 Patch；Store
模板不应暗示这些能力已经可运行。

## 自动发布

发布工作流调用仓库根目录的 `./gradlew`，因此使用模板前必须先在插件仓库根目录生成并提交 Gradle Wrapper：

```powershell
gradle wrapper --gradle-version 9.6.1
git add gradlew gradlew.bat gradle/wrapper/gradle-wrapper.jar gradle/wrapper/gradle-wrapper.properties
git update-index --chmod=+x gradlew
git commit -m "Add Gradle Wrapper for plugin releases"
```

提交中必须同时包含 `gradlew`、`gradlew.bat`、`gradle/wrapper/gradle-wrapper.jar` 和
`gradle/wrapper/gradle-wrapper.properties`。缺少任一文件时，GitHub Actions 无法执行模板中的
`./gradlew packageNpl`。在 Windows 上也要提交 Unix 启动脚本，并通过上述 `git update-index` 保留其可执行位。

把 `store/github-release-workflow.yml` 复制到你的仓库 `.github/workflows/`，准备好
`manifest.template.json` 与 `tools/` 中的脚本，然后推送 `v*` tag：

- 工作流构建 `.npl` 并运行 `tools/validate-npl.ps1` 校验；
- 用 `tools/sign-plugin.ps1` 把 `packageUrl`、`sha256`、`size` 写入当前版本条目；
- 创建 GitHub Release 并上传 `.npl` 与 `manifest.json`，随后把清单推回仓库的动态默认分支。

工作流只需要 `contents: write` 权限；不需要 `id-token`、审批 API 地址或任何 Secret。

## 手工发布

```powershell
./tools/publish-plugin.ps1 -Repo owner/repo -Tag v1.0.0 -Package build/npl/plugin-v1.0.0.npl -Manifest manifest.template.json
```

脚本会在本地生成绑定好哈希与体积的 `manifest.json`；上传 Release 后把该文件提交到默认分支即可。

## 申请官方源收录

插件稳定后，可以向官方源仓库提交 PR，在 `plugins.json` 中新增条目（参考
`store/plugins-entry.template.json`）。`manifestUrl` 指向插件仓库的 `manifest.json`，`manifestSha256` 是
该文件的 SHA-256。收录由社区公开审核，仅影响商店内的来源标识，不影响 Topic 发现与安装。

## 已废弃

审批 API、GitHub OIDC 认证客户端、逐版本签发材料与 `HMCLCE_APPROVAL_API_URL` 配置均已移除。
旧版 `certification` 字段仅为兼容旧数据保留。
