# HMCL CE 插件发布与商店收录

HMCL CE 通过两类来源发现插件，都会显示在启动器的插件商店中：

- **GitHub Topic 发现（社区模式，默认）**：任何公开仓库添加全小写 Topic `hmclce`，并在默认分支根目录提供 `manifest.json`（schema v2），启动器即可自动发现并列出其中的插件版本。不需要审批 API、开发者证书或人工复核。
- **官方源（已认证标识）**：由社区维护的 `HMCL-CE-Plugin-Store` 仓库以 `plugins.json` 索引收录经审核的插件，条目通过 `manifestUrl` 指向各插件自己的 `manifest.json`。被收录的插件在商店中显示已认证来源标识；这只是来源标签，不是安装前提。商店仓库自身由官方密钥签名，启动器内置对应的信任根。

## 社区发布清单

1. 公开 GitHub 仓库，添加全小写 Topic：`hmclce`。
2. 默认分支根目录放置 `manifest.json`（schema v2，模板见 `store/manifest.template.json`）。
3. 每个 `versions[]` 条目对应一个 Release：tag 使用 `v<SemVer>`，附件上传对应 `.npl`；`packageUrl` 指向该附件，`sha256` 与 `size` 必须和实际上传的字节一致。
4. `launcherVersion`、`pluginApiVersion`（当前为 4）、`permissions` / `requiredPermissions` 与包内 `plugin.json` 保持一致。

启动器在安装前校验：仓库清单结构、插件 ID、版本、下载地址、SHA-256、依赖与权限声明，并向用户展示来源与权限信息；包含 Mixin 的插件需要额外确认，并在重启后加载。

## 自动发布

把 `store/github-release-workflow.yml` 复制到你的仓库 `.github/workflows/`，准备好 `manifest.template.json` 与 `tools/` 中的脚本，然后推送 `v*` tag：

- 工作流构建 `.npl` 并运行 `tools/validate-npl.ps1` 校验；
- 用 `tools/sign-plugin.ps1` 把 `packageUrl`、`sha256`、`size` 写入当前版本条目，生成 `manifest.json`；
- 创建 GitHub Release 并上传 `.npl` 与 `manifest.json`，随后把 `manifest.json` 推回默认分支。

工作流只需要 `contents: write` 权限；不需要 `id-token`、审批 API 地址或任何 Secret。

## 手工发布

```powershell
./tools/publish-plugin.ps1 -Repo owner/repo -Tag v1.0.0 -Package build/npl/plugin-v1.0.0.npl -Manifest manifest.template.json
```

脚本会在本地生成绑定好哈希与体积的 `manifest.json`；上传 Release 后把该文件提交到默认分支即可。

## 申请官方源收录

插件稳定后，可以向官方源仓库提交 PR，在 `plugins.json` 中新增条目（参考 `store/plugins-entry.template.json`）：`manifestUrl` 指向你仓库的 `manifest.json`，`manifestSha256` 是该文件的 SHA-256。收录由社区公开审核，仅影响商店内的来源标识，不影响 Topic 发现与安装。

## 已废弃

审批 API、GitHub OIDC 认证客户端、逐版本签发材料与 `HMCLCE_APPROVAL_API_URL` 配置均已移除，CE 不再要求社区开发者接入任何审批服务。旧版 `certification` 字段仅为兼容旧数据保留。
