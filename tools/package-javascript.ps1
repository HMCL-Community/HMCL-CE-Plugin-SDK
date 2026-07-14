# Package JavaScript plugin as .npl
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root 'examples\javascript-helloworld'
$outDir = Join-Path $project 'build\npl'
$out = Join-Path $outDir 'dev.hmclnex.example.javascript.helloworld-v1.0.0.npl'
$zip = [System.IO.Path]::ChangeExtension($out, '.zip')
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
if (Test-Path $out) { Remove-Item $out -Force }
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $project 'plugin.json'), (Join-Path $project 'main.js') -DestinationPath $zip
Move-Item -LiteralPath $zip -Destination $out
Write-Host "Created $out"
