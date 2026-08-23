# HMCL CE 插件发布与认证要求

本文档描述 HMCL CE 当前的第三方插件发现、仓库复核、逐版本 NPL 认证和在线吊销规则。旧的开发者私钥、开发者证书和手工提交中心列表流程已经停用。

## 发布模式

| 模式 | 发现方式 | 版本证明 | HMCL CE 显示 |
| --- | --- | --- | --- |
| 社区插件 | GitHub Topic `hmclce` | 无 | 社区来源，安装前确认来源与权限 |
| 官方认证第三方插件 | GitHub Topic `hmclce` | 仓库状态 + 当前 NPL 的 `artifactAttestation` | 仅在在线状态新鲜且双验证均有效时显示“官方认证” |
| 官方插件 | 官方签名索引 | `official-repository` 角色 | 官方来源 |

认证只证明仓库身份、审核状态和某一组不可变 NPL 字节之间的绑定关系，不替代插件权限授权，也不会把第三方插件提升为官方插件。

## 双验证规则

一个第三方版本只有同时满足以下条件才会获得认证标签：

1. 审批服务确认 GitHub 数字仓库 ID、规范化 `owner/repository`、Topic、默认分支、源码提交和插件 ID 范围。
2. 仓库最近一次成功复核仍在七天有效期内，并且在线状态为 `approved`。
3. 审批服务从绑定的 GitHub Release asset ID 自行下载 NPL，而不是信任调用者提交的下载 URL、摘要或大小。
4. 当前 NPL 的包结构、`plugin.json`、权限、依赖、ID、版本、tag、提交、SHA-256 和字节数均通过校验。
5. `versions[].certification.artifactAttestation` 的 Ed25519 签名和所有绑定字段有效。
6. 最新签名状态快照没有吊销该仓库、该 NPL SHA-256 或实际签发证明的 Ed25519 key ID。

仓库认证不会自动覆盖新版本。每次发布新的 `.npl`，即使插件 ID 和版本号看起来未变，也必须重新审批。相同插件 ID 和版本对应不同字节会被拒绝。

## 最新发布门槛

- 使用公开、未归档、未禁用且不是 Fork 的 GitHub 仓库。
- Topics 包含全小写 `hmclce`；界面显示名称仍可使用 `HMCLCE`。
- 默认分支根目录提供 schema v2 `manifest.json`。
- Git tag 使用 `v<SemVer>`，例如 `v1.2.0`；清单中必须恰好存在对应的 `1.2.0`。
- `.npl` 根目录提供 schema v4 `plugin.json`。
- `plugin.json` 显式声明 `permissions`、`requiredPermissions` 和 `launcherVersion`。
- 商店清单声明精确 HTTPS `packageUrl`、小写 SHA-256、字节数和 `pluginApiVersion: 4`。
- 商店清单的 ID、版本、权限、必要权限和依赖与 NPL 内的 `plugin.json` 完全一致。
- 一个发布工作流只能选择并审批一个 NPL，避免资产名称或证明绑定歧义。
- 已发布 tag、Release asset 和证明不可覆盖；修复内容必须发布新版本。

## 仓库结构

```text
my-plugin/
├── .github/workflows/release.yml
├── manifest.template.json
├── manifest.json
├── plugin.json
├── README.md
├── tools/
│   ├── validate-npl.ps1
│   ├── sign-plugin.ps1
│   └── request-certification.ps1
└── build/npl/my-plugin-v1.2.0.npl
```

- `manifest.template.json` 是未认证输入，提交到源码仓库。
- `sign-plugin.ps1` 只计算包摘要和生成未认证清单，不持有或使用认证私钥。
- `request-certification.ps1` 在 GitHub Actions 中取得 OIDC token，并调用审批 API。
- `manifest.json` 由工作流生成并提交到默认分支，禁止手工添加或复制其他版本的证明。
- `.github/workflows/release.yml` 可从 `store/github-release-workflow.yml` 复制后调整构建命令。

## NPL 清单

所有新包使用 schema v4：

```json
{
  "schemaVersion": 4,
  "id": "com.example.hello",
  "name": "Hello World Plugin",
  "version": "1.2.0",
  "author": "Example Author",
  "description": "Example plugin",
  "type": "java",
  "entrypoint": "com.example.hello.HelloPlugin",
  "dependencies": [],
  "permissions": ["launcher-ui"],
  "requiredPermissions": [],
  "launcherVersion": ">=26.8-beta.3-fix"
}
```

`requiredPermissions` 必须是 `permissions` 的子集。Mixin 插件必须在两个数组中都包含 `mixin`，并通过 `mixins` 数组列出配置文件。`launcherVersion` 应填写实际测试通过的版本范围。

## 商店清单

`manifest.template.json` 保存未认证 payload：

```json
{
  "schemaVersion": 2,
  "id": "com.example.hello",
  "repository": "github.com/owner/hello-plugin",
  "license": "GPL-3.0-or-later",
  "website": "https://github.com/owner/hello-plugin",
  "source": "https://github.com/owner/hello-plugin",
  "readmeUrl": "https://raw.githubusercontent.com/owner/hello-plugin/main/README.md",
  "versions": [
    {
      "version": "1.2.0",
      "packageUrl": "https://github.com/owner/hello-plugin/releases/download/v1.2.0/com.example.hello-v1.2.0.npl",
      "sha256": "64 位小写十六进制 SHA-256",
      "launcherVersion": ">=26.8-beta.3-fix",
      "requiredJavaVersion": "17",
      "pluginApiVersion": 4,
      "permissions": ["launcher-ui"],
      "requiredPermissions": [],
      "dependencies": [],
      "requiresRestart": false,
      "channel": "stable",
      "size": 102400,
      "releaseNotes": "Release notes",
      "releaseDate": "2026-08-14"
    }
  ]
}
```

认证成功后，工作流只在对应的 `versions[]` 元素中加入证明：

```json
{
  "certification": {
    "artifactAttestation": {
      "signed": {
        "_type": "npl-attestation",
        "schemaVersion": 1,
        "repository": "owner/hello-plugin",
        "repositoryId": 123456,
        "pluginId": "com.example.hello",
        "version": "1.2.0",
        "tag": "v1.2.0",
        "assetName": "com.example.hello-v1.2.0.npl",
        "assetUrl": "https://github.com/owner/hello-plugin/releases/download/v1.2.0/com.example.hello-v1.2.0.npl",
        "sha256": "64 位小写十六进制 SHA-256",
        "size": 102400,
        "sourceCommit": "40 位小写 Git commit SHA",
        "repositoryVerificationId": "服务端签发的复核 ID",
        "approvedAt": "2026-08-14T10:00:00Z",
        "policyVersion": "2026-08-14",
        "jobId": "审批任务 ID"
      },
      "signatures": [
        {
          "keyId": "ed25519:...",
          "signature": "Base64 Ed25519 签名"
        }
      ]
    }
  }
}
```

证明同时绑定仓库数字 ID、源码提交和仓库复核 ID。复制其他仓库、版本或资产的证明不会通过校验。

## 社区发布

1. 给 GitHub 仓库添加 Topic `hmclce`。
2. 复制 `store/manifest.template.json` 并填写元数据。
3. 复制 `store/github-release-workflow.yml` 到 `.github/workflows/release.yml`。
4. 创建 Repository Variable `HMCLCE_PLUGIN_RELEASE_MODE=community`。
5. 推送形如 `v1.2.0` 的 tag。

社区发布不需要审批 API，也不需要向官方 Store 提交 PR。手工发布脚本仅支持该模式：

```powershell
./tools/publish-plugin.ps1 -Repo owner/hello-plugin -Tag v1.2.0 `
  -Package build/npl/com.example.hello-v1.2.0.npl `
  -Manifest manifest.template.json -Community
```

## 认证发布

### GitHub 配置

设置以下 Repository Variables：

| 名称 | 值 |
| --- | --- |
| `HMCLCE_PLUGIN_RELEASE_MODE` | `certified` |
| `HMCLCE_APPROVAL_API_URL` | 官方审批服务的 HTTPS 基础地址 |

工作流顶层必须具有：

```yaml
permissions:
  contents: write
  id-token: write
```

工作流引用的第三方 Action 必须固定到完整 commit SHA，不能只写 `@v4` 或分支名。升级 Action 时由
Dependabot/Renovate 提交独立 PR，审查上游变更后再更新 SHA，避免可移动标签改变已经审查过的认证流水线。

不要配置 `HMCLCE_PLUGIN_SIGNING_KEY`、`HMCLCE_PLUGIN_CERTIFICATE` 或长期审批 API Key。工作流和 SDK 会主动拒绝这些旧变量。

### 自动流程

1. 构建并在本地校验唯一一个 NPL。
2. 生成尚未包含认证证明的 `manifest.pending.json`。
3. 创建草稿 GitHub Release，并上传 NPL。
4. 获取该草稿资产的 GitHub numeric asset ID。
5. 请求 audience 为 `hmclce-plugin-approval` 的 GitHub Actions OIDC token。
6. 调用仓库注册接口，按返回的不可变 `verificationId` 状态地址轮询，直到当前 tag 提交和插件 ID 获批。
7. 把获批的 `repositoryVerificationId`、tag、commit 和 asset ID 一并提交到 NPL 审批接口。
8. 轮询 NPL 任务状态；服务端通过 GitHub App 权限自行下载草稿资产。
9. 比对服务端返回的摘要、大小和所有证明字段，再把证明写入当前版本。
10. 上传 `manifest.json` 和分离证明，并将同一份 `manifest.json` 更新到默认分支。
11. 前述步骤全部成功后，最后把 Release 从草稿改为公开。

任何审批、下载、签名或字段比对失败都会使 Release 保持草稿状态。

### 审批 API

SDK 当前使用以下接口：

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| `POST` | `/api/v1/repositories/registrations` | 注册或触发当前仓库复核 |
| `GET` | `/api/v1/repositories/verifications/{verificationId}` | 轮询本次不可变的仓库复核记录 |
| `POST` | `/api/v1/releases` | 提交 repository verification ID、tag、commit、asset ID、asset name、插件 ID 和版本 |
| `GET` | `/api/v1/releases/{jobId}` | 查询审批结果和 `artifactAttestation` |

受保护的提交请求使用 `Authorization: Bearer <GitHub OIDC token>`，响应使用 `{ "data": ... }` 包装。状态 URL 是同源且绑定本次 `verificationId`/`jobId` 的公开只读资源。服务端以 OIDC claims 中的仓库、数字仓库 ID、tag ref、workflow 和 commit 为准，不接受 JSON 字段覆盖身份；NPL 审批只接受已批准且尚未过期的精确仓库验证 ID。

## 在线状态与吊销

HMCL CE 根元数据包含固定的 HTTPS 状态地址和三个互相隔离的在线角色：

- `repository-attestor` 签仓库复核证明。
- `artifact-attestor` 签不可变 NPL 证明。
- `trust-status` 签在线状态快照。

客户端启动或打开商店时尝试刷新，之后至多每六小时一次。响应支持 ETag，缓存以原子方式写入，并记录已经接受的最高单调版本。低版本、较早生成时间、无效签名、超过 48 小时有效窗口或已过期的快照不能替换缓存。

新安装和更新必须使用未过期状态。网络失败时可以在签名缓存的有效期内继续判断；缓存过期后不会伪造认证或把未知状态错误显示为吊销。最新有效快照明确吊销的已安装 NPL 会在加载前隔离，并显示原因代码。

## 发布前检查

```powershell
./tools/validate-npl.ps1 -Package build/npl/com.example.hello-v1.2.0.npl
./tools/test-request-certification.ps1
```

还应在支持的最低 HMCL CE 与 Java 组合上完成安装、权限确认、重启加载、更新和卸载测试。

## 信任边界

- HMCL CE 构建通过 Repository Variable `HMCLCE_PLUGIN_ROOT_JSON` 注入公开根元数据；根公钥无需保密。
- 根元数据中的 `statusUrl` 由发行方固定，插件清单不能替换状态服务器。
- 离线根私钥和三个在线角色私钥不得进入 SDK、插件仓库或插件工作流。
- 审批服务的签名操作应位于独立进程、KMS 或 HSM 边界，并按角色隔离。
- GitHub OIDC token 短期有效，只能证明本次工作流身份，不能导出官方签名能力。
- NPL 的 SHA-256 和精确字节数同时受清单、证明和下载后校验约束。
