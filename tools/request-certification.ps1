param(
    [Parameter(Mandatory = $true)][string]$ApiBase,
    [Parameter(Mandatory = $true)][string]$Repository,
    [Parameter(Mandatory = $true)][string]$Tag,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$CommitSha,
    [Parameter(Mandatory = $true)][ValidateRange(1, [long]::MaxValue)][long]$AssetId,
    [Parameter(Mandatory = $true)][string]$AssetName,
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][string]$Manifest,
    [Parameter(Mandatory = $true)][string]$OutputManifest,
    [Parameter(Mandatory = $true)][string]$OutputAttestation,
    [string]$OidcToken,
    [ValidateRange(0, 60)][int]$PollIntervalSeconds = 3,
    [ValidateRange(10, 3600)][int]$TimeoutSeconds = 600
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$audience = 'hmclce-plugin-approval'
$maxSafeInteger = [long]9007199254740991

function Assert-Condition([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function ConvertTo-SafePositiveInteger($Value, [string]$Name) {
    $isNumeric = $Value -is [byte] -or $Value -is [sbyte] `
        -or $Value -is [int16] -or $Value -is [uint16] `
        -or $Value -is [int32] -or $Value -is [uint32] `
        -or $Value -is [int64] -or $Value -is [uint64] `
        -or $Value -is [decimal] -or $Value -is [double] -or $Value -is [single]
    Assert-Condition $isNumeric "$Name must be a numeric safe integer."
    try {
        $number = [decimal]$Value
    } catch {
        throw "$Name must be a numeric safe integer."
    }
    Assert-Condition (
        [decimal]::Truncate($number) -eq $number -and
        $number -ge 1 -and
        $number -le $maxSafeInteger
    ) "$Name must be a positive safe integer no greater than $maxSafeInteger."
    return [long]$number
}

function Normalize-Repository([string]$Value) {
    $normalized = $Value.Trim().TrimEnd('/')
    $normalized = $normalized -replace '^https://github\.com/', ''
    $normalized = $normalized -replace '^http://github\.com/', ''
    $normalized = $normalized -replace '^github\.com/', ''
    $normalized = $normalized -replace '\.git$', ''
    Assert-Condition ($normalized -cmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})/[A-Za-z0-9._-]{1,100}$') 'Repository must be a canonical GitHub owner/repository identity.'
    return $normalized.ToLowerInvariant()
}

function Read-ProblemResponse($Exception) {
    try {
        if ($null -eq $Exception.Response) {
            return $Exception.Message
        }
        $stream = $Exception.Response.GetResponseStream()
        if ($null -eq $stream) {
            return $Exception.Message
        }
        $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8)
        try {
            $text = $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $Exception.Message
        }
        try {
            $problem = $text | ConvertFrom-Json
            if (-not [string]::IsNullOrWhiteSpace([string]$problem.detail)) {
                return [string]$problem.detail
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$problem.title)) {
                return [string]$problem.title
            }
        } catch {
            # Preserve the bounded response text when it is not a Problem Details document.
        }
        return $text.Substring(0, [Math]::Min(2048, $text.Length))
    } catch {
        return $Exception.Message
    }
}

function Invoke-ApprovalRequest(
    [string]$Method,
    [string]$Uri,
    [string]$Bearer,
    $Body
) {
    $headers = @{ Authorization = "Bearer $Bearer"; Accept = 'application/json' }
    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -TimeoutSec 30
        }
        $json = $Body | ConvertTo-Json -Depth 30 -Compress
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType 'application/json' -Body $json -TimeoutSec 30
    } catch {
        $detail = Read-ProblemResponse $_.Exception
        throw "HMCL CE approval API request failed: $detail"
    }
}

function Get-GitHubOidcToken {
    if (-not [string]::IsNullOrWhiteSpace($OidcToken)) {
        return $OidcToken.Trim()
    }
    $requestUrl = $env:ACTIONS_ID_TOKEN_REQUEST_URL
    $requestToken = $env:ACTIONS_ID_TOKEN_REQUEST_TOKEN
    if ([string]::IsNullOrWhiteSpace($requestUrl) -or [string]::IsNullOrWhiteSpace($requestToken)) {
        throw 'GitHub OIDC environment is unavailable. Grant the workflow permission id-token: write.'
    }
    $separator = if ($requestUrl.Contains('?')) { '&' } else { '?' }
    $uri = $requestUrl + $separator + 'audience=' + [uri]::EscapeDataString($audience)
    try {
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = "Bearer $requestToken" } -TimeoutSec 30
    } catch {
        throw "GitHub OIDC token request failed: $(Read-ProblemResponse $_.Exception)"
    }
    if ([string]::IsNullOrWhiteSpace([string]$response.value)) {
        throw 'GitHub OIDC endpoint returned no token.'
    }
    return [string]$response.value
}

function Resolve-ApiUri([string]$Base, [string]$Location) {
    if ([uri]::IsWellFormedUriString($Location, [System.UriKind]::Absolute)) {
        $resolved = [uri]$Location
    } else {
        $resolved = [uri]::new(([uri]($Base.TrimEnd('/') + '/')), $Location.TrimStart('/'))
    }
    $baseUri = [uri]$Base
    Assert-Condition ([string]::IsNullOrEmpty($resolved.UserInfo)) 'Approval API polling URLs must not contain embedded credentials.'
    Assert-Condition ([string]::IsNullOrEmpty($resolved.Fragment)) 'Approval API polling URLs must not contain fragments.'
    $sameScheme = [System.StringComparer]::OrdinalIgnoreCase.Equals($resolved.Scheme, $baseUri.Scheme)
    $sameHost = [System.StringComparer]::OrdinalIgnoreCase.Equals($resolved.IdnHost, $baseUri.IdnHost)
    Assert-Condition ($sameScheme -and $sameHost -and $resolved.Port -eq $baseUri.Port) 'Approval API returned a polling URL on a different origin.'
    return $resolved.AbsoluteUri
}

function Write-Utf8Json([string]$Path, $Value) {
    $parent = Split-Path -Parent ([System.IO.Path]::GetFullPath($Path))
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }
    [System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($Path), (($Value | ConvertTo-Json -Depth 100) + "`n"), $utf8)
}

$baseUri = $null
Assert-Condition ([uri]::TryCreate(($ApiBase.Trim().TrimEnd('/') + '/'), [System.UriKind]::Absolute, [ref]$baseUri)) 'Approval API base URL must be absolute.'
$isLoopback = $baseUri.IsLoopback
Assert-Condition ($baseUri.Scheme -ceq 'https' -or ($baseUri.Scheme -ceq 'http' -and $isLoopback)) 'Approval API must use HTTPS; HTTP is accepted only for loopback tests.'
Assert-Condition ([string]::IsNullOrEmpty($baseUri.UserInfo)) 'Approval API base URL must not contain embedded credentials.'
Assert-Condition ([string]::IsNullOrEmpty($baseUri.Query) -and [string]::IsNullOrEmpty($baseUri.Fragment)) 'Approval API base URL must not contain a query or fragment.'
Assert-Condition (-not [string]::IsNullOrWhiteSpace($baseUri.IdnHost)) 'Approval API base URL must contain a host.'
ConvertTo-SafePositiveInteger $AssetId 'AssetId' | Out-Null
$canonicalRepository = Normalize-Repository $Repository
$resolvedPackage = (Resolve-Path -LiteralPath $Package).Path
$resolvedManifest = (Resolve-Path -LiteralPath $Manifest).Path
Assert-Condition ($AssetName -cmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,250}\.npl$') 'AssetName must be a safe ASCII .npl filename no longer than 255 characters.'
Assert-Condition ($Tag -cmatch '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$') 'Tag must be v followed by a semantic version.'

$document = Get-Content -LiteralPath $resolvedManifest -Raw | ConvertFrom-Json
Assert-Condition ([int]$document.schemaVersion -eq 2) 'Certification requires a schemaVersion 2 store manifest.'
$pluginId = [string]$document.id
Assert-Condition ($pluginId.Length -le 160 -and $pluginId -cmatch '^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)+$') 'Manifest plugin ID must be canonical lower-case text with at least one separator.'
$manifestRepository = Normalize-Repository ([string]$document.repository)
Assert-Condition ($manifestRepository -ceq $canonicalRepository) 'Manifest repository does not match the GitHub Actions repository.'
$version = $Tag.Substring(1)
$matchingVersions = @($document.versions | Where-Object { [string]$_.version -ceq $version })
Assert-Condition ($matchingVersions.Count -eq 1) "Manifest must contain exactly one versions[] entry for $version."
$release = $matchingVersions[0]
$packageUrl = "https://github.com/$canonicalRepository/releases/download/$Tag/$AssetName"
$sha256 = (Get-FileHash -LiteralPath $resolvedPackage -Algorithm SHA256).Hash.ToLowerInvariant()
$size = (Get-Item -LiteralPath $resolvedPackage).Length
$release.packageUrl = $packageUrl
$release.sha256 = $sha256
$release.size = $size

$deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
$registrationToken = Get-GitHubOidcToken
$registrationResponse = Invoke-ApprovalRequest `
    -Method Post `
    -Uri ([uri]::new($baseUri, 'api/v1/repositories/registrations').AbsoluteUri) `
    -Bearer $registrationToken `
    -Body ([ordered]@{ repository = $canonicalRepository; sourceCommit = $CommitSha.ToLowerInvariant() })
$registration = $registrationResponse.data
Assert-Condition ($null -ne $registration) 'Repository registration response has no data object.'
Assert-Condition ((Normalize-Repository ([string]$registration.repository)) -ceq $canonicalRepository) 'Repository registration response changed the repository identity.'
Assert-Condition (-not [string]::IsNullOrWhiteSpace([string]$registration.verificationId)) 'Repository registration response has no verification ID.'
$repositoryId = ConvertTo-SafePositiveInteger $registration.repositoryId 'Repository registration response repositoryId'
Assert-Condition (-not [string]::IsNullOrWhiteSpace([string]$registration.statusUrl)) 'Repository registration response has no status URL.'
$repositoryStatusUri = Resolve-ApiUri $baseUri.AbsoluteUri ([string]$registration.statusUrl)
$repositoryVerificationId = [string]$registration.verificationId
$approvedRepository = $null
while ([DateTimeOffset]::UtcNow -lt $deadline) {
    $state = ([string]$registration.status).ToLowerInvariant()
    if ($state -ceq 'approved') {
        $approvedRepository = $registration
        break
    }
    if ($state -in @('failed', 'suspended', 'revoked')) {
        $reason = if (@($registration.findings).Count -eq 0) { 'No verification findings were provided.' } else { (@($registration.findings) | ConvertTo-Json -Depth 20 -Compress) }
        throw "Repository verification ended in state '$state': $reason"
    }
    Assert-Condition ($state -in @('queued', 'processing')) "Repository verification returned an unsupported state: $state"
    if ($PollIntervalSeconds -gt 0) {
        Start-Sleep -Seconds $PollIntervalSeconds
    }
    $registrationResponse = Invoke-ApprovalRequest -Method Get -Uri $repositoryStatusUri -Bearer $registrationToken -Body $null
    $registration = $registrationResponse.data
    Assert-Condition ($null -ne $registration) 'Repository verification status response has no data object.'
    Assert-Condition ([string]$registration.verificationId -ceq $repositoryVerificationId) 'Repository verification status changed the immutable verification ID.'
    $statusRepositoryId = ConvertTo-SafePositiveInteger $registration.repositoryId 'Repository verification status repositoryId'
    Assert-Condition ($statusRepositoryId -eq $repositoryId) 'Repository verification status changed the numeric repository ID.'
    Assert-Condition ((Normalize-Repository ([string]$registration.repository)) -ceq $canonicalRepository) 'Repository verification status changed the repository identity.'
}
Assert-Condition ($null -ne $approvedRepository) "Repository verification did not finish within $TimeoutSeconds seconds."
Assert-Condition ([string]$approvedRepository.sourceCommit -ceq $CommitSha.ToLowerInvariant()) 'Repository verification approved a different source commit.'
Assert-Condition (@($approvedRepository.pluginIds) -ccontains $pluginId) 'Repository verification does not authorize this plugin ID.'
Assert-Condition (-not [string]::IsNullOrWhiteSpace([string]$approvedRepository.nextVerificationAt)) 'Repository verification has no next verification time.'
try {
    $nextVerificationAt = [DateTimeOffset]::Parse([string]$approvedRepository.nextVerificationAt, [Globalization.CultureInfo]::InvariantCulture)
} catch {
    throw 'Repository verification returned an invalid next verification time.'
}
Assert-Condition ($nextVerificationAt -gt [DateTimeOffset]::UtcNow) 'Repository verification is already stale.'

$releaseToken = Get-GitHubOidcToken
$releaseResponse = Invoke-ApprovalRequest `
    -Method Post `
    -Uri ([uri]::new($baseUri, 'api/v1/releases').AbsoluteUri) `
    -Bearer $releaseToken `
    -Body ([ordered]@{
        repository = $canonicalRepository
        repositoryVerificationId = $repositoryVerificationId
        tag = $Tag
        sourceCommit = $CommitSha.ToLowerInvariant()
        assetId = $AssetId
        assetName = $AssetName
        pluginId = $pluginId
        version = $version
    })
$job = $releaseResponse.data
Assert-Condition ($null -ne $job -and -not [string]::IsNullOrWhiteSpace([string]$job.jobId)) 'Release submission returned no job ID.'
Assert-Condition (-not [string]::IsNullOrWhiteSpace([string]$job.statusUrl)) 'Release submission returned no status URL.'
$statusUri = Resolve-ApiUri $baseUri.AbsoluteUri ([string]$job.statusUrl)
$approved = $null
while ([DateTimeOffset]::UtcNow -lt $deadline) {
    $statusResponse = Invoke-ApprovalRequest -Method Get -Uri $statusUri -Bearer $releaseToken -Body $null
    $status = $statusResponse.data
    Assert-Condition ($null -ne $status) 'Release status response has no data object.'
    $state = ([string]$status.status).ToLowerInvariant()
    if ($state -in @('approved', 'succeeded', 'completed')) {
        $approved = $status
        break
    }
    if ($state -in @('rejected', 'failed', 'cancelled', 'revoked')) {
        $reason = if ([string]::IsNullOrWhiteSpace([string]$status.detail)) { 'No approval detail was provided.' } else { [string]$status.detail }
        throw "NPL certification ended in state '$state': $reason"
    }
    Assert-Condition ($state -in @('queued', 'pending', 'verifying', 'processing')) "Release status returned an unsupported state: $state"
    if ($PollIntervalSeconds -gt 0) {
        Start-Sleep -Seconds $PollIntervalSeconds
    }
}
Assert-Condition ($null -ne $approved) "NPL certification did not finish within $TimeoutSeconds seconds."

Assert-Condition ([string]$approved.sha256 -ceq $sha256) 'Approval service SHA-256 does not match the local NPL package.'
Assert-Condition ([int64]$approved.size -eq $size) 'Approval service size does not match the local NPL package.'
Assert-Condition ([string]$approved.jobId -ceq [string]$job.jobId) 'Approval service returned a result for a different job.'
$attestation = $approved.artifactAttestation
Assert-Condition ($null -ne $attestation -and $null -ne $attestation.signed -and @($attestation.signatures).Count -ge 1) 'Approval service returned an incomplete artifact attestation.'
$signed = $attestation.signed
Assert-Condition ([string]$signed._type -ceq 'npl-attestation' -and [int]$signed.schemaVersion -eq 1) 'Approval service returned an unsupported artifact attestation.'
Assert-Condition ((Normalize-Repository ([string]$signed.repository)) -ceq $canonicalRepository) 'Artifact attestation repository does not match.'
$attestedRepositoryId = ConvertTo-SafePositiveInteger $signed.repositoryId 'Artifact attestation repositoryId'
Assert-Condition ($attestedRepositoryId -eq $repositoryId) 'Artifact attestation repository ID does not match the verified repository.'
Assert-Condition ([string]$signed.pluginId -ceq $pluginId) 'Artifact attestation plugin ID does not match.'
Assert-Condition ([string]$signed.version -ceq $version) 'Artifact attestation version does not match.'
Assert-Condition ([string]$signed.tag -ceq $Tag) 'Artifact attestation tag does not match.'
Assert-Condition ([string]$signed.assetName -ceq $AssetName) 'Artifact attestation asset name does not match.'
Assert-Condition ([string]$signed.assetUrl -ceq $packageUrl) 'Artifact attestation asset URL does not match.'
Assert-Condition ([string]$signed.sha256 -ceq $sha256) 'Artifact attestation SHA-256 does not match the local NPL package.'
Assert-Condition ([int64]$signed.size -eq $size) 'Artifact attestation size does not match the local NPL package.'
Assert-Condition ([string]$signed.sourceCommit -ceq $CommitSha.ToLowerInvariant()) 'Artifact attestation source commit does not match the GitHub tag build.'
Assert-Condition ([string]$signed.repositoryVerificationId -ceq $repositoryVerificationId) 'Artifact attestation is bound to a different repository verification.'
Assert-Condition ([string]$signed.jobId -ceq [string]$job.jobId) 'Artifact attestation is bound to a different approval job.'
Assert-Condition (-not [string]::IsNullOrWhiteSpace([string]$signed.policyVersion)) 'Artifact attestation has no policy version.'
foreach ($signature in @($attestation.signatures)) {
    Assert-Condition ([string]$signature.keyId -cmatch '^ed25519:[0-9a-f]{64}$') 'Artifact attestation contains an invalid signing key ID.'
    try {
        $signatureBytes = [Convert]::FromBase64String([string]$signature.signature)
    } catch {
        throw 'Artifact attestation contains a non-Base64 signature.'
    }
    Assert-Condition ($signatureBytes.Length -eq 64) 'Artifact attestation contains an invalid Ed25519 signature length.'
}

$certification = [pscustomobject]@{ artifactAttestation = $attestation }
$release | Add-Member -MemberType NoteProperty -Name certification -Value $certification -Force
Write-Utf8Json -Path $OutputAttestation -Value $attestation
Write-Utf8Json -Path $OutputManifest -Value $document

Write-Host "Certified NPL: $AssetName"
Write-Host "Approval job: $([string]$approved.jobId)"
Write-Host "SHA-256: $sha256"
Write-Host "Manifest: $OutputManifest"
