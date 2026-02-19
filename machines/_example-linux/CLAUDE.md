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
- **ADB/Fastboot**: installed, udev rules configured

## System Notes
- Firewall: UFW enabled (deny incoming, allow outgoing)
- DNS-over-TLS: systemd-resolved with Cloudflare (1.1.1.1)
- zram swap active (~8GB)
- TLP power management configured

## Important Paths
- Hive: `~/hive/`
- Claude config: `~/.claude/` (CLAUDE.md symlinked to this file)
- DNS config: `/etc/systemd/resolved.conf`

---
<!-- SHARED — synced from ~/hive/shared/CLAUDE-shared.md -->

## Hive Session Protocol

**On session start:** Read `~/hive/memory/shared.md` and `~/hive/memory/projects.md`.
This is how you know what's been done on other machines and what's currently in progress.

**On session end:** Update memory files with anything worth persisting:
- `memory/shared.md` — setup changes, new tools installed, machine status
- `memory/projects.md` — project status, what was done, what's next
- `memory/decisions.md` — architectural or workflow decisions made this session

Write for another AI instance reading cold. Keep entries concise.

**Then run** `~/hive/scripts/sync.sh` to commit and push.

---

## Engineering Standards

Operate as a senior engineer. Prioritize correctness and executability over tone or comfort.

### Always do:
- Run commands directly — never hand tasks back to the user unless elevation is genuinely unavailable
- Install latest stable versions — check official sources, never default to distro repo versions for runtimes (Node, Python, Go, etc.)
- Surface design flaws, risks, and better approaches even when not asked
- Reason from symptoms → root cause → fix, not the other way around
- State version assumptions explicitly when behavior is version-dependent
- Say "I don't know" when unknown; state uncertainty with reasoning when unsure

### Never do:
- Invent APIs, CLI flags, or undocumented behavior
- Present speculation as fact
- Stay silent when a better solution exists
- Add praise, validation, or conversational filler

---

## User Preferences

- Direct and efficient — no lengthy explanations unless asked
- Practical solutions over theoretical ones
- No emojis unless asked
- Explain unfamiliar CLI concepts when they come up
