# h1ve machine setup for Windows
# Generates ~/.claude/settings.json with PowerShell->Git Bash wrapped hooks.
# Do NOT copy shared/settings.json on Windows — it uses $HOME which the WSL shim breaks.
#
# Usage (PowerShell):
#   .\setup-machine.ps1 <machine-name>
#   .\setup-machine.ps1              (lists profiles and prompts)
#
# Requires: Git for Windows installed, h1ve cloned to ~\h1ve

param([string]$MachineName = "")

$ErrorActionPreference = "Stop"
$RepoRoot   = Split-Path -Parent $PSScriptRoot
$ClaudeDir  = "$env:USERPROFILE\.claude"

# Detect Git Bash
$GitBashCandidates = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe"
)
$GitBashPath = $GitBashCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $GitBashPath) {
    Write-Error "Git Bash not found. Install Git for Windows first (https://git-scm.com)."
    exit 1
}

# List machines if no name provided
if (-not $MachineName) {
    Write-Host "Available machine profiles:"
    Get-ChildItem "$RepoRoot\machines" -Directory | ForEach-Object { Write-Host "  $($_.Name)" }
    Write-Host ""
    $MachineName = Read-Host "Machine name"
}

$MachineDir = "$RepoRoot\machines\$MachineName"
$ClaudeMd   = "$MachineDir\CLAUDE.md"

if (-not (Test-Path "$MachineDir\machine.md")) {
    Write-Error "No machine.md at machines\$MachineName\. Create it first."
    exit 1
}

# Convert Windows path to forward-slash Git Bash path
function ToGitBashPath($path) {
    $path = $path -replace '\\', '/'
    if ($path -match '^([A-Za-z]):') {
        $path = '/' + $matches[1].ToLower() + $path.Substring(2)
    }
    return $path
}

$RepoRootGb         = ToGitBashPath $RepoRoot
$SessionStartScript = "$RepoRootGb/scripts/session-start.sh"
$SyncScript         = "$RepoRootGb/scripts/sync.sh"
$GitBashFwd         = ToGitBashPath $GitBashPath

Write-Host ""
Write-Host "Setting up: $MachineName"
Write-Host "Repo root:  $RepoRoot"
Write-Host "Git Bash:   $GitBashPath"
Write-Host ""

# 1. Build CLAUDE.md if needed
Write-Host "[1/4] Building CLAUDE.md..."
if (-not (Test-Path $ClaudeMd)) {
    & $GitBashPath "$RepoRootGb/scripts/propagate.sh"
    Write-Host "  Built"
} else {
    Write-Host "  CLAUDE.md already exists — skipping rebuild"
}

# 2. Symlink CLAUDE.md
Write-Host "[2/4] Wiring symlink..."
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
if (Test-Path "$ClaudeDir\CLAUDE.md") {
    Remove-Item "$ClaudeDir\CLAUDE.md" -Force
}
New-Item -ItemType SymbolicLink -Path "$ClaudeDir\CLAUDE.md" -Target $ClaudeMd | Out-Null
Write-Host "  Linked"

# 3. Write settings.json — merge hooks, preserve other settings
Write-Host "[3/4] Writing ~/.claude/settings.json..."

$SettingsPath = "$ClaudeDir\settings.json"
$SessionStartCmd = "powershell.exe -NoProfile -Command `"& '$GitBashFwd' '$SessionStartScript'`""
$SyncCmd         = "powershell.exe -NoProfile -Command `"& '$GitBashFwd' '$SyncScript'`""

# Load or create settings
if (Test-Path $SettingsPath) {
    $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json
} else {
    $json = [PSCustomObject]@{}
}

# Build hook objects
$newHooks = [PSCustomObject]@{
    SessionStart = @(
        [PSCustomObject]@{
            matcher = "startup|resume|clear"
            hooks   = @([PSCustomObject]@{ type = "command"; command = $SessionStartCmd; timeout = 15 })
        }
    )
    SessionEnd = @(
        [PSCustomObject]@{
            hooks = @([PSCustomObject]@{ type = "command"; command = $SyncCmd; timeout = 30 })
        }
    )
    PreCompact = @(
        [PSCustomObject]@{
            hooks = @([PSCustomObject]@{ type = "command"; command = $SyncCmd; timeout = 30 })
        }
    )
}

# Merge: overwrite hooks section, preserve everything else
if ($json.PSObject.Properties['hooks']) {
    $json.hooks = $newHooks
} else {
    $json | Add-Member -MemberType NoteProperty -Name hooks -Value $newHooks
}
if (-not $json.PSObject.Properties['autoMemoryDirectory']) {
    $json | Add-Member -MemberType NoteProperty -Name autoMemoryDirectory -Value '~/h1ve/memory/claude'
}

$json | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding UTF8
Write-Host "  Written with PowerShell-wrapped hooks"

# 4. Verify
Write-Host "[4/4] Verifying..."
$errors = 0

$item = Get-Item "$ClaudeDir\CLAUDE.md" -ErrorAction SilentlyContinue
if ($item -and $item.LinkType -eq "SymbolicLink" -and (Test-Path $ClaudeMd)) {
    Write-Host "  OK    ~/.claude/CLAUDE.md symlink"
} else {
    Write-Host "  FAIL  ~/.claude/CLAUDE.md symlink broken or missing"
    $errors++
}

$loaded = Get-Content $SettingsPath -Raw | ConvertFrom-Json
foreach ($event in @("SessionStart", "SessionEnd", "PreCompact")) {
    $found = $false
    foreach ($entry in $loaded.hooks.$event) {
        foreach ($hook in $entry.hooks) {
            if ($hook.command -like "*h1ve*") { $found = $true; break }
        }
        if ($found) { break }
    }
    if ($found) { Write-Host "  OK    $event hook" }
    else        { Write-Host "  FAIL  $event hook missing"; $errors++ }
}

Write-Host ""
if ($errors -eq 0) {
    Write-Host "Setup complete. $MachineName is ready."
    Write-Host "Start a Claude Code session to verify hooks fire."
} else {
    Write-Host "Setup finished with $errors error(s). Review output above."
    exit 1
}
