param(
    [string]$Project
)

# Package JavaScript plugin as a reproducible .npl archive.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Project)) {
    $Project = Join-Path $root 'examples\javascript-helloworld'
}
$project = (Resolve-Path -LiteralPath $Project).Path
$outDir = Join-Path $project 'build\npl'
$out = Join-Path $outDir 'dev.hmclnex.example.javascript.helloworld-v1.0.0.npl'
$zip = [System.IO.Path]::ChangeExtension($out, '.zip')
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
if (Test-Path $out) { Remove-Item $out -Force }
if (Test-Path $zip) { Remove-Item $zip -Force }

Add-Type -AssemblyName System.IO.Compression
$entries = @(
    [pscustomobject]@{ Name = 'plugin.json'; Source = (Join-Path $project 'plugin.json') }
    [pscustomobject]@{ Name = 'main.js'; Source = (Join-Path $project 'main.js') }
)
$fixedTimestamp = [System.DateTimeOffset]::new(1980, 1, 2, 0, 0, 0, [System.TimeSpan]::Zero)
$outputStream = [System.IO.File]::Open(
    $zip,
    [System.IO.FileMode]::CreateNew,
    [System.IO.FileAccess]::Write,
    [System.IO.FileShare]::None
)
try {
    $archive = [System.IO.Compression.ZipArchive]::new(
        $outputStream,
        [System.IO.Compression.ZipArchiveMode]::Create,
        $true,
        [System.Text.Encoding]::UTF8
    )
    try {
        foreach ($item in $entries) {
            $entry = $archive.CreateEntry($item.Name, [System.IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = $fixedTimestamp
            $entry.ExternalAttributes = 0
            $inputStream = [System.IO.File]::OpenRead($item.Source)
            $entryStream = $entry.Open()
            try {
                $inputStream.CopyTo($entryStream)
            } finally {
                $entryStream.Dispose()
                $inputStream.Dispose()
            }
        }
    } finally {
        $archive.Dispose()
    }
} finally {
    $outputStream.Dispose()
}

Move-Item -LiteralPath $zip -Destination $out
Write-Host "Created $out"
Write-Host "SHA-256: $((Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash.ToLowerInvariant())"
