param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [string]$Model = "default",

    [string]$Role = "implementer",

    [string]$ResumeSessionId = "",

    [switch]$ReadOnly
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Protect Claude subscription: prevent accidental fallback to pay-as-you-go Console API
if (Test-Path Env:ANTHROPIC_API_KEY) {
    Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
}

if (-not (Test-Path $ProjectDir)) {
    throw "ProjectDir not found: $ProjectDir"
}

$orchDir = Join-Path $ProjectDir ".orchestration"
if (-not (Test-Path $orchDir)) {
    New-Item -ItemType Directory -Path $orchDir -Force | Out-Null
}

$logFile = Join-Path $orchDir "comm_log.jsonl"
$jsDataFile = Join-Path $orchDir "dashboard_data.js"

# Build Claude Code CLI arguments
$cliArgs = @(
    "-p", $Prompt,
    "--output-format", "json"
)

if (-not [string]::IsNullOrWhiteSpace($Model) -and $Model -ne "default") {
    $cliArgs += @("--model", $Model)
}

if (-not [string]::IsNullOrWhiteSpace($ResumeSessionId)) {
    $cliArgs += @("--resume", $ResumeSessionId)
}

if ($ReadOnly) {
    $cliArgs += @("--allowedTools", "Read,Grep,Glob,LS")
}

# Resolve unmodified official Claude Code binary (prefer direct .exe to avoid wrapper stderr noise)
$claudeExe = $null
$candidatePaths = @(
    (Join-Path $env:APPDATA "npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe"),
    (Join-Path $env:USERPROFILE ".local\bin\claude.exe")
)

foreach ($cand in $candidatePaths) {
    if ($cand -and (Test-Path $cand)) {
        $claudeExe = $cand
        break
    }
}

if (-not $claudeExe) {
    $claudeCmd = Get-Command claude.exe -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        $claudeExe = $claudeCmd.Source
    } else {
        $cmdFallback = Get-Command claude -ErrorAction SilentlyContinue
        if ($cmdFallback) {
            $claudeExe = $cmdFallback.Source
        } else {
            throw "Claude Code CLI ('claude') not found. Please install Claude Code and ensure it is in your PATH."
        }
    }
}

$startTime = Get-Date
$timestampStart = $startTime.ToString("o")

# Log outgoing Neon -> Claude request
$reqEntry = [ordered]@{
    timestamp  = $timestampStart
    direction  = "neon_to_claude"
    sender     = "Gemini 4 Neon (Orchestrator)"
    recipient  = "Claude Code ($Model)"
    role       = $Role
    read_only  = [bool]$ReadOnly
    session_id = $ResumeSessionId
    message    = $Prompt
} | ConvertTo-Json -Compress -Depth 5

Add-Content -Path $logFile -Value $reqEntry -Encoding UTF8

# Execute official Claude Code CLI with stdin closed immediately and stdout/stderr separated
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $claudeExe
$psi.WorkingDirectory = $ProjectDir
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

$escapedArgs = $cliArgs | ForEach-Object {
    $a = $_ -replace '(\\*)"', '$1$1\"'
    $a = $a -replace '(\\+)$', '$1$1'
    '"' + $a + '"'
}
$psi.Arguments = $escapedArgs -join " "

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
[void]$proc.Start()
$proc.StandardInput.Close()

$stdoutTask = $proc.StandardOutput.ReadToEndAsync()
$stderrTask = $proc.StandardError.ReadToEndAsync()
$proc.WaitForExit()

$rawOutput = $stdoutTask.Result
$rawError = $stderrTask.Result
$exitCode = $proc.ExitCode

$endTime = Get-Date
$durationMs = [int](($endTime - $startTime).TotalMilliseconds)

# Parse JSON output if available
$sessionIdOut = $ResumeSessionId
$replyText = $rawOutput.Trim()
if ([string]::IsNullOrWhiteSpace($replyText) -and -not [string]::IsNullOrWhiteSpace($rawError)) {
    $replyText = $rawError.Trim()
}

try {
    $parsed = $rawOutput | ConvertFrom-Json -ErrorAction Stop
    if ($parsed.session_id) { $sessionIdOut = $parsed.session_id }
    if ($parsed.result) { $replyText = $parsed.result }
} catch {
    # Keep raw text if CLI returned non-JSON output
}

# Log incoming Claude -> Neon response
$resEntry = [ordered]@{
    timestamp   = $endTime.ToString("o")
    direction   = "claude_to_neon"
    sender      = "Claude Code ($Model)"
    recipient   = "Gemini 4 Neon (Orchestrator)"
    role        = $Role
    read_only   = [bool]$ReadOnly
    session_id  = $sessionIdOut
    duration_ms = $durationMs
    exit_code   = $exitCode
    message     = $replyText
} | ConvertTo-Json -Compress -Depth 5

Add-Content -Path $logFile -Value $resEntry -Encoding UTF8

# Regenerate dashboard_data.js so dashboard.html works offline via file:// without CORS errors
$allLines = Get-Content -Path $logFile -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$jsPayload = "window.ORCHESTRATION_LOGS = [`n" + ($allLines -join ",`n") + "`n];"
Set-Content -Path $jsDataFile -Value $jsPayload -Encoding UTF8

# Emit clean summary JSON to stdout for Antigravity Neon to parse
$summary = [ordered]@{
    status      = if ($exitCode -eq 0) { "ok" } else { "error" }
    exit_code   = $exitCode
    model       = $Model
    role        = $Role
    session_id  = $sessionIdOut
    duration_ms = $durationMs
    result      = $replyText
}
$summary | ConvertTo-Json -Depth 5
