# My Windows Machine — Claude Instructions

## Machine
- **Model**: Dell XPS 15 9530
- **CPU**: Intel Core i9-13900H (14 cores / 20 threads)
- **RAM**: 32GB
- **GPU**: NVIDIA RTX 4060 + Intel Iris Xe
- **Storage**: 1TB NVMe SSD
- **Role**: Gaming + heavy compute

## OS
- **Windows**: Windows 11 Pro 23H2
- **WSL2**: Ubuntu 22.04

## Environment
- **Claude Code running in**: WSL2 — symlink and hooks live inside WSL
- **Primary shell**: WSL2 (Ubuntu) for dev work, PowerShell for Windows-native tasks

## Tools Installed
- **Node.js**: v22.x LTS (via nvm inside WSL2)
- **Python**: 3.12 (via pyenv inside WSL2)
- **Claude Code**: latest (global, via npm inside WSL2)
- **git**: 2.43 (WSL2) / **gh**: 2.45 (WSL2)

## Important Paths
- Windows home: `C:\Users\<username>\`
- WSL home: `/home/<username>/`
- Hive (WSL): `~/hive/`
- Claude config (WSL): `~/.claude/` (CLAUDE.md symlinked to machines/_example-windows-wsl/CLAUDE.md)

## System Notes
- Windows Defender exclusions set for WSL2 dev directories (speeds up builds)
- Commands requiring Windows-level elevation (not WSL sudo) need a PowerShell admin window — flag these explicitly rather than silently skipping

## Hook Setup
Claude Code runs inside WSL2 — hooks use the standard Linux pattern:
```bash
cp ~/hive/shared/settings.json ~/.claude/settings.json
```
For native Windows (Git Bash, not WSL2), see `machines/_example-windows-native/`.
