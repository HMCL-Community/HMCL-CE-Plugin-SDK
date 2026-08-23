$ErrorActionPreference = 'Stop'

function Assert-Condition([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    } finally {
        $listener.Stop()
    }
}

function Start-ApprovalFixture([int]$Port, [string]$Sha256, [int64]$Size, [switch]$WrongDigest) {
    return Start-Job -ArgumentList $Port, $Sha256, $Size, ([bool]$WrongDigest) -ScriptBlock {
        param($FixturePort, $ExpectedSha256, $ExpectedSize, $ReturnWrongDigest)
        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add("http://127.0.0.1:$FixturePort/")
        $listener.Start()
        try {
            for ($requestIndex = 0; $requestIndex -lt 4; $requestIndex++) {
                $context = $listener.GetContext()
                $request = $context.Request
                $response = $context.Response
                $response.ContentType = 'application/json'
                $response.StatusCode = if ($request.HttpMethod -eq 'GET') { 200 } else { 202 }
                $authorization = $request.Headers['Authorization']
                if ($authorization -cne 'Bearer fixture-oidc-token') {
                    $response.StatusCode = 401
                    $body = '{"type":"https://approval.invalid/problems/unauthorized","title":"Unauthorized","status":401}'
                } elseif ($request.Url.AbsolutePath -eq '/api/v1/repositories/registrations') {
                    $body = '{"data":{"verificationId":"11111111-1111-4111-8111-111111111111","repositoryId":42,"repository":"owner/repo","sourceCommit":"0123456789abcdef0123456789abcdef01234567","status":"queued","pluginIds":[],"statusUrl":"/api/v1/repositories/verifications/11111111-1111-4111-8111-111111111111"}}'
                } elseif ($request.Url.AbsolutePath -eq '/api/v1/repositories/verifications/11111111-1111-4111-8111-111111111111') {
                    $body = '{"data":{"verificationId":"11111111-1111-4111-8111-111111111111","repositoryId":42,"repository":"owner/repo","sourceCommit":"0123456789abcdef0123456789abcdef01234567","status":"approved","pluginIds":["dev.hmclce.fixture"],"nextVerificationAt":"2099-08-21T10:00:00Z","statusUrl":"/api/v1/repositories/verifications/11111111-1111-4111-8111-111111111111"}}'
                } elseif ($request.Url.AbsolutePath -eq '/api/v1/releases') {
                    $reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
                    try { $releaseRequest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
                    if ([string]$releaseRequest.repositoryVerificationId -cne '11111111-1111-4111-8111-111111111111') {
                        $response.StatusCode = 400
                        $body = '{"title":"Repository verification binding missing","status":400}'
                    } else {
                    $body = "{`"data`":{`"jobId`":`"job-1`",`"status`":`"queued`",`"statusUrl`":`"/api/v1/releases/job-1`"}}"
                    }
                } elseif ($request.Url.AbsolutePath -eq '/api/v1/releases/job-1') {
                    $digest = if ($ReturnWrongDigest) { 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' } else { $ExpectedSha256 }
                    $body = @{
                        data = @{
                            jobId = 'job-1'
                            status = 'approved'
                            sha256 = $digest
                            size = $ExpectedSize
                            artifactAttestation = @{
                                signed = [ordered]@{
                                    _type = 'npl-attestation'
                                    schemaVersion = 1
                                    repository = 'owner/repo'
                                    repositoryId = 42
                                    pluginId = 'dev.hmclce.fixture'
                                    version = '1.2.3'
                                    tag = 'v1.2.3'
                                    assetName = 'fixture.npl'
                                    assetUrl = 'https://github.com/owner/repo/releases/download/v1.2.3/fixture.npl'
                                    sha256 = $digest
                                    size = $ExpectedSize
                                    sourceCommit = '0123456789abcdef0123456789abcdef01234567'
                                    repositoryVerificationId = '11111111-1111-4111-8111-111111111111'
                                    approvedAt = '2026-08-14T10:00:00Z'
                                    policyVersion = '2026-08-14'
                                    jobId = 'job-1'
                                }
                                signatures = @(@{
                                    keyId = 'ed25519:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                                    signature = [Convert]::ToBase64String([byte[]](0..63))
                                })
                            }
                        }
                    } | ConvertTo-Json -Depth 20 -Compress
                } else {
                    $response.StatusCode = 404
                    $body = '{"type":"https://approval.invalid/problems/not-found","title":"Not Found","status":404}'
                }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                $response.Close()
            }
        } finally {
            $listener.Stop()
            $listener.Close()
        }
    }
}

$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ('hmclce-cert-client-test-' + [guid]::NewGuid())
[void](New-Item -ItemType Directory -Path $temporary)
try {
    $package = Join-Path $temporary 'fixture.npl'
    [System.IO.File]::WriteAllBytes($package, [byte[]](0..255))
    $sha256 = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
    $size = (Get-Item -LiteralPath $package).Length
    $manifest = Join-Path $temporary 'manifest.template.json'
    @{
        schemaVersion = 2
        id = 'dev.hmclce.fixture'
        repository = 'github.com/owner/repo'
        versions = @(@{
            version = '1.2.3'
            packageUrl = 'https://github.com/owner/repo/releases/download/v1.2.3/fixture.npl'
            sha256 = $sha256
            size = $size
        })
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifest -Encoding utf8

    $unsafeAssetRejected = $false
    try {
        & (Join-Path $PSScriptRoot 'request-certification.ps1') `
            -ApiBase 'http://127.0.0.1:1' `
            -Repository 'owner/repo' `
            -Tag 'v1.2.3' `
            -CommitSha '0123456789abcdef0123456789abcdef01234567' `
            -AssetId 122 `
            -AssetName 'fixture unsafe.npl' `
            -Package $package `
            -Manifest $manifest `
            -OutputManifest (Join-Path $temporary 'unsafe-manifest.json') `
            -OutputAttestation (Join-Path $temporary 'unsafe-attestation.json') `
            -OidcToken 'fixture-oidc-token'
    } catch {
        $unsafeAssetRejected = $_.Exception.Message -match 'safe ASCII'
    }
    Assert-Condition $unsafeAssetRejected 'Certification client accepted an asset name that cannot be bound canonically to its GitHub URL.'

    $unsafeAssetIdRejected = $false
    try {
        & (Join-Path $PSScriptRoot 'request-certification.ps1') `
            -ApiBase 'http://127.0.0.1:1' `
            -Repository 'owner/repo' `
            -Tag 'v1.2.3' `
            -CommitSha '0123456789abcdef0123456789abcdef01234567' `
            -AssetId 9007199254740992 `
            -AssetName 'fixture.npl' `
            -Package $package `
            -Manifest $manifest `
            -OutputManifest (Join-Path $temporary 'unsafe-id-manifest.json') `
            -OutputAttestation (Join-Path $temporary 'unsafe-id-attestation.json') `
            -OidcToken 'fixture-oidc-token'
    } catch {
        $unsafeAssetIdRejected = $_.Exception.Message -match 'safe integer'
    }
    Assert-Condition $unsafeAssetIdRejected 'Certification client accepted an asset ID that cannot be represented exactly across protocol implementations.'

    $credentialedApiRejected = $false
    try {
        & (Join-Path $PSScriptRoot 'request-certification.ps1') `
            -ApiBase 'http://user:password@127.0.0.1:1' `
            -Repository 'owner/repo' `
            -Tag 'v1.2.3' `
            -CommitSha '0123456789abcdef0123456789abcdef01234567' `
            -AssetId 121 `
            -AssetName 'fixture.npl' `
            -Package $package `
            -Manifest $manifest `
            -OutputManifest (Join-Path $temporary 'credentialed-api-manifest.json') `
            -OutputAttestation (Join-Path $temporary 'credentialed-api-attestation.json') `
            -OidcToken 'fixture-oidc-token'
    } catch {
        $credentialedApiRejected = $_.Exception.Message -match 'credentials'
    }
    Assert-Condition $credentialedApiRejected 'Certification client accepted credentials embedded in the approval API URL.'

    $port = Get-FreeTcpPort
    $fixture = Start-ApprovalFixture -Port $port -Sha256 $sha256 -Size $size
    $outputManifest = Join-Path $temporary 'manifest.json'
    $outputAttestation = Join-Path $temporary 'fixture.attestation.json'
    try {
        & (Join-Path $PSScriptRoot 'request-certification.ps1') `
            -ApiBase "http://127.0.0.1:$port" `
            -Repository 'owner/repo' `
            -Tag 'v1.2.3' `
            -CommitSha '0123456789abcdef0123456789abcdef01234567' `
            -AssetId 123 `
            -AssetName 'fixture.npl' `
            -Package $package `
            -Manifest $manifest `
            -OutputManifest $outputManifest `
            -OutputAttestation $outputAttestation `
            -OidcToken 'fixture-oidc-token' `
            -PollIntervalSeconds 0 `
            -TimeoutSeconds 15
        Wait-Job $fixture -Timeout 5 | Out-Null
        $published = Get-Content -LiteralPath $outputManifest -Raw | ConvertFrom-Json
        Assert-Condition ($published.versions[0].certification.artifactAttestation.signed.sha256 -ceq $sha256) 'Artifact attestation was not attached to the matching version.'
        Assert-Condition ((Get-Content -LiteralPath $outputAttestation -Raw | ConvertFrom-Json).signed.jobId -ceq 'job-1') 'Detached attestation output is invalid.'
    } finally {
        Stop-Job $fixture -ErrorAction SilentlyContinue
        Remove-Job $fixture -Force -ErrorAction SilentlyContinue
    }

    $badPort = Get-FreeTcpPort
    $badFixture = Start-ApprovalFixture -Port $badPort -Sha256 $sha256 -Size $size -WrongDigest
    $rejected = $false
    try {
        & (Join-Path $PSScriptRoot 'request-certification.ps1') `
            -ApiBase "http://127.0.0.1:$badPort" `
            -Repository 'owner/repo' `
            -Tag 'v1.2.3' `
            -CommitSha '0123456789abcdef0123456789abcdef01234567' `
            -AssetId 124 `
            -AssetName 'fixture.npl' `
            -Package $package `
            -Manifest $manifest `
            -OutputManifest (Join-Path $temporary 'bad-manifest.json') `
            -OutputAttestation (Join-Path $temporary 'bad-attestation.json') `
            -OidcToken 'fixture-oidc-token' `
            -PollIntervalSeconds 0 `
            -TimeoutSeconds 15
    } catch {
        $rejected = $_.Exception.Message -match 'SHA-256'
    } finally {
        Stop-Job $badFixture -ErrorAction SilentlyContinue
        Remove-Job $badFixture -Force -ErrorAction SilentlyContinue
    }
    Assert-Condition $rejected 'Certification client accepted an attestation for different package bytes.'

    Write-Host 'Certification API client tests passed.'
} finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}
