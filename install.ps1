$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceDir = Join-Path $scriptRoot "skills\neon-claude-orchestrator"
$targetDir = Join-Path $HOME ".gemini\config\skills\neon-claude-orchestrator"

if (-not (Test-Path $sourceDir)) {
    throw "Source skill directory not found: $sourceDir"
}

$parentDir = Split-Path -Parent $targetDir
if (-not (Test-Path $parentDir)) {
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

Copy-Item -Path $sourceDir -Destination $parentDir -Recurse -Force

Write-Host "Installed neon-claude-orchestrator skill to: $targetDir" -ForegroundColor Green
Write-Host "Restart or open a new conversation in Antigravity to start using it."
