# One check before every commit: formatting, analyzer, tests.
# Run from client-app:  powershell -File tool/check.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)

Write-Host '== format'
dart format --output=none --set-exit-if-changed lib test tool
if ($LASTEXITCODE -ne 0) { Write-Host 'Run: dart format lib test tool'; exit 1 }

Write-Host '== analyze'
flutter analyze
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host '== test'
flutter test
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host 'All checks passed'
