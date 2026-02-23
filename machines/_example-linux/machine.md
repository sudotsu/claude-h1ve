# My Linux Machine — Claude Instructions

## Machine
- **Model**: ThinkPad X1 Carbon Gen 11
- **CPU**: Intel Core i7-1365U (10 cores / 12 threads)
- **RAM**: 16GB
- **GPU**: Intel Iris Xe (integrated)
- **Storage**: 512GB NVMe SSD
- **Role**: Primary dev machine

## OS
- **Distro**: Ubuntu 24.04 LTS
- **Desktop**: GNOME 46
- **Kernel**: 6.8.0-45-generic

## Tools Installed
- **Node.js**: v22.x LTS (via NodeSource)
- **Python**: 3.12 system-managed — use venv or pipx for installs
- **Package manager**: pnpm preferred
- **Claude Code**: latest (global, via npm)
- **Gemini CLI**: latest (global, via npm)
- **git**: 2.43 / **gh**: 2.45

## System Notes
- Firewall: UFW enabled (deny incoming, allow outgoing)
- DNS-over-TLS: systemd-resolved with Cloudflare (1.1.1.1)
- zram swap active (~8GB)
- TLP power management configured

## Important Paths
- Hive: `~/hive/`
- Claude config: `~/.claude/` (CLAUDE.md symlinked to machines/_example-linux/CLAUDE.md)
- DNS config: `/etc/systemd/resolved.conf`

## Hook Setup
Hooks use the standard Linux pattern from `shared/settings.json`:
```bash
cp ~/hive/shared/settings.json ~/.claude/settings.json
```
