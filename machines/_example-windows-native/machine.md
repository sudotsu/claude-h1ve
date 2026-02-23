# My Windows Machine (Native) — Claude Instructions

## Machine
- **Model**: Dell XPS 15 9530
- **CPU**: Intel Core i9-13900H (14 cores / 20 threads)
- **RAM**: 32GB
- **GPU**: NVIDIA RTX 4060 + Intel Iris Xe
- **Storage**: 1TB NVMe SSD
- **Role**: Primary dev machine

## OS
- **Windows**: Windows 11 Pro 23H2
- **WSL2**: Ubuntu 22.04 (installed but Claude Code runs natively, not inside WSL)

## Environment
- **Claude Code running in**: Native Windows with Git Bash as shell
- **Primary shell**: Git Bash (`C:/Program Files/Git/bin/bash.exe`)

## Tools Installed (Windows-native)
- **Node.js**: v22.x LTS (Windows installer) / npm latest
- **Python**: 3.12 (Windows installer)
- **Claude Code**: latest (global, via npm — `npm install -g @anthropic-ai/claude-code`)
- **git**: latest (git-scm.com) / **gh**: latest (cli.github.com)

## Important Paths
- Windows home: `C:\Users\<username>\`
- Git Bash equivalent: `/c/Users/<username>/`
- Hive repo: `C:\Users\<username>\hive\` (also `/c/Users/<username>/hive/` in Git Bash)
- Claude config: `C:\Users\<username>\.claude\` (CLAUDE.md symlinked to machines/_example-windows-native/CLAUDE.md)

## Windows-Specific Notes
- Paths use forward slashes in Git Bash (`/c/Users/<username>/`) but backslashes in native Windows
- Some operations require elevated PowerShell (admin) — Claude will tell you exactly what to run rather than silently skipping
- **Hooks use a PowerShell→Git Bash wrapper** (see Hook Setup below) — do NOT copy `shared/settings.json` directly, it will break silently

## Hook Setup
Claude Code's hook runner resolves `/bin/bash` to the WSL shim (`C:\Windows\System32\bash.exe`),
not Git Bash. The WSL shim cannot resolve Git Bash paths, so standard hooks silently fail.

Fix: create `C:\Users\<username>\.claude\settings.json` manually with the PowerShell wrapper:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [{
          "type": "command",
          "command": "powershell.exe -NoProfile -Command \"& 'C:/Program Files/Git/bin/bash.exe' 'C:/Users/<username>/hive/scripts/session-start.sh'\"",
          "timeout": 15
        }]
      }
    ],
    "Stop": [
      {
        "hooks": [{
          "type": "command",
          "command": "powershell.exe -NoProfile -Command \"& 'C:/Program Files/Git/bin/bash.exe' 'C:/Users/<username>/hive/scripts/sync.sh'\"",
          "timeout": 30
        }]
      }
    ]
  }
}
```

Replace `<username>` with your Windows username. This bypasses the WSL shim entirely by
routing through PowerShell to invoke Git Bash directly by full path.

**Why this is necessary:** Three bash binaries exist on Windows+WSL in PATH priority order:
`C:\Windows\System32\bash.exe` (WSL shim) → WSL app alias → `C:\Program Files\Git\bin\bash.exe` (Git Bash).
Node.js (which runs Claude Code) finds the WSL shim first. The shim cannot resolve
Git Bash-style paths (`/c/Users/...`) or Windows paths (`C:\Users\...`). The PowerShell
wrapper bypasses this entirely.
