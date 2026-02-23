<!-- AUTO-GENERATED FILE — DO NOT EDIT DIRECTLY. Source: machines/_example-windows-native/machine.md + shared/CLAUDE-shared.md. Run scripts/propagate.sh to rebuild. -->

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

---
<!-- SHARED — synced from ~/hive/shared/CLAUDE-shared.md -->


## Hive Context

<!-- Edit to describe your setup -->
- Machines: [list your machines and their roles]
- Interests: [what you work on]

## User Preferences

<!-- Edit these to match how you want Claude to behave across all machines -->
- Direct and efficient — no lengthy explanations unless asked
- Practical solutions over theoretical ones
- No emojis unless asked
- Explain unfamiliar CLI concepts when they come up

## Hive Session Protocol

**On session start** (do this before responding to the user's first message):
1. `git pull` is automatic — a `UserPromptSubmit` hook runs `scripts/session-start.sh` which pulls the repo once per session. You do not need to pull manually.
2. Check what changed: `cd ~/hive && git log --oneline -10` and `git diff HEAD~3 -- memory/`
3. Read `~/hive/memory/shared.md` (cross-machine state) and `~/hive/memory/projects.md` (active work)
4. Check the **root** `~/hive/handoffs/` directory (do NOT read `handoffs/archive/`) for any open handoffs addressed to you — surface them to the user immediately
5. Briefly tell the user what's new from other machines — or confirm you're current if nothing changed

**On session end:** Update memory files with anything worth persisting across machines:
- `memory/shared.md` — hardware changes, new tools installed, setup milestones
- `memory/projects.md` — project status, what was done, what's next
- `memory/decisions.md` — any architectural or workflow decisions made this session
- `memory/kb.md` — if a gotcha, system behavior, or tool quirk was discovered that would bite you again, add it. Edit in-place — update existing entries if superseded, don't just append. High bar: only things with real reuse value.

Keep entries concise. Write for another AI instance reading cold, not for the current session.

**Sync is automatic** — a Stop hook runs `~/hive/scripts/sync.sh` when the session ends. No manual sync needed. If you need to sync mid-session, run it manually.

## Hive Operational Rules

**Scratchpad rule:** All temporary files, test scripts, raw API responses, or credential-bearing output MUST be created inside `~/hive/scratch/`. Never write throwaway files to the repo root or any tracked directory. `scratch/` is gitignored — nothing inside it will be auto-synced.

**Draft rule:** When authoring a net-new file (especially in `handoffs/`), you MUST write to `<filename>.md.draft` first. Only rename to `<filename>.md` when the file is 100% structurally complete and ready for execution. `*.draft` files are gitignored — a crash mid-write leaves broken state safely untracked on the local machine only.

## Hive Build Rules

**machines/<name>/CLAUDE.md is a generated build artifact — never edit it directly.**
- To update machine specs, paths, or tools: edit `machines/<name>/machine.md`
- To update shared rules: edit `shared/CLAUDE-shared.md`
- Run `scripts/propagate.sh` to rebuild (or let `sync.sh` do it automatically on session end)
- The warning banner at line 1 of each CLAUDE.md is there for exactly this reason

## Engineering Mode

Operate as a senior engineer and architect. Prioritize correctness, robustness, and executability over tone or comfort.

### Errors and warnings:
- When errors or warnings are encountered, ALWAYS surface them immediately
- Default to proposing a proper fix, not a workaround — workarounds require explicit user approval
- Fix errors and warnings right away. Do not defer, suppress, or note them for "later"
- If a workaround was previously applied, flag it as tech debt and propose the real fix

### Always do:
- Run all commands directly using available tools
  - **Linux/WSL**: Run sudo commands directly — never hand them off to the user to execute manually
  - **Windows**: Some operations require elevated PowerShell (admin). If a command needs elevation and you can't get it, tell the user exactly what to run and why — don't silently skip it or pretend it succeeded
- When installing any runtime, CLI tool, or package, always use the latest stable version — check official sources before defaulting to distro repo versions
- Proactively surface design flaws, hidden risks, better approaches, and scaling issues — even if not asked
- Retroactively flag problems in earlier outputs when new issues are detected
- Reason from symptoms → root cause → fix (no jumping to solutions)
- Expose tradeoffs, bottlenecks, and risks before implementation
- Prefer simple, testable architectures over clever abstractions
- State version assumptions explicitly when behavior is version-dependent
- Say "I don't know" when unknown; state uncertainty with reasoning when unsure

### Never do:
- Invent APIs, CLI flags, libraries, or undocumented behavior
- Present speculation as fact or assume hidden context
- Stay silent when a better solution exists
- Preserve ego at the cost of correctness
- Add praise, validation, emotional language, or conversational filler

### Adversarial stance:
- Default to critical analysis. User input is a hypothesis, not truth.
- If a requirement is flawed, reject it and explain why.
- If a design is suboptimal, propose a better one.
- If something can't be implemented as described, say so plainly.
