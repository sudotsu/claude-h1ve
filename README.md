# claude-h1ve

> Every new Claude session starts blank. New machine, new terminal, new project — blank slate. You've re-explained your stack, your preferences, your context hundreds of times.

**claude-h1ve** fixes that. One git repo. Every Claude instance you work with reads the same instructions, the same memory, the same context — automatically, on every machine you own.

---

## The difference

**Without claude-h1ve — every session, every machine:**

> **You:** I need help with my project
>
> **Claude:** I'd be happy to help! Could you tell me about your project and what stack you're working with?
>
> **You:** *[re-explains everything. again.]*

New terminal. Different machine. Context window cleared. Same conversation.
You're not just re-explaining your project — you're re-explaining *you*.
Your preferences, your stack, your OS, your tools, your standards, what you were in the middle of.
Every. Single. Time.

---

**With claude-h1ve — what Claude reads automatically at session start:**

```
# My Laptop — Claude Instructions

## Machine
- Framework 13, Intel Core i7-1370P, 32GB RAM, Fedora 40
- Role: primary dev machine

## Tools
- Node.js v22 (nvm), pnpm, Python 3.12, Claude Code, gh
```

```
# memory/projects.md

## api-refactor
- Status: in progress
- Done: JWT access tokens working
- Next: refresh token rotation
```

```
# shared/CLAUDE-shared.md (built into every machine's CLAUDE.md)

## User Preferences
- Direct and efficient — no lengthy explanations unless asked
- Practical solutions over theoretical ones
- Run commands directly, never hand tasks back to the user
```

**Same conversation now:**

> **You:** I need help with my project
>
> **Claude:** You're on the JWT middleware — access tokens are done, refresh rotation is next.
> You're on your laptop (Fedora 40, Node 22, pnpm). What's the issue?

---

**Switch machines. Pick up where you left off.**

Sessions end, the hive syncs automatically. Next machine you sit down at, Claude already
knows what was done and what's next — without you saying a word.

---

## How it works

### The file Claude reads

Claude Code loads `~/.claude/CLAUDE.md` as global instructions at the start of every session.
claude-h1ve replaces that file with a symlink into this repo:

```
machines/<name>/machine.md  ──┐
                               ├──▶ propagate.sh ──▶ machines/<name>/CLAUDE.md
shared/CLAUDE-shared.md    ──┘                              │
                                                         symlink
                                                            │
                                                   ~/.claude/CLAUDE.md
                                                   (Claude reads this)
```

`machine.md` is the editable source — your hardware specs, installed tools, OS-specific notes.
`CLAUDE-shared.md` is the source of truth for rules shared across all machines — preferences,
engineering standards, session protocol.

`CLAUDE.md` is a **generated artifact**. `propagate.sh` builds it by concatenating both sources.
Never edit `CLAUDE.md` directly — changes are silently overwritten on the next build.

### The hooks

Two Claude Code hooks automate the sync lifecycle:

```
Session starts
    │
    └──▶ UserPromptSubmit hook ──▶ session-start.sh ──▶ git pull (once per session)

Session ends
    │
    └──▶ Stop hook ──▶ sync.sh ──▶ propagate.sh ──▶ git add -A ──▶ commit + push
```

Every session starts with the latest hive state pulled from GitHub.
Every session ends with any changes committed and pushed automatically.

### The memory layer

Memory files live in `memory/` and are read by Claude on every session start:

| File | What goes here |
|------|----------------|
| `memory/shared.md` | Machine status, cross-machine environment notes |
| `memory/projects.md` | Active projects, what's done, what's next |
| `memory/decisions.md` | Architectural decisions — so future sessions don't re-debate settled questions |
| `memory/kb.md` | Gotchas, system behaviors, fixes worth knowing again — strict schema enforced |

---

## What this is not

- Not a prompt hack or "make AI smarter" trick
- Not a cloud service or third-party dependency
- Not project-specific — this is global, persistent infrastructure for your AI workflow

---

## Install

**Requires:** [Claude Code](https://claude.ai/code) · [GitHub CLI](https://cli.github.com/) · git

**Step 1:** Click **"Use this template"** → **"Create a new repository"** (top right of this page).
Name it `claude-h1ve`, set visibility to your preference.

**Step 2:** Run the installer (replace `YOUR-USERNAME`):

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/claude-h1ve/main/install.sh | bash
```

Or manually:

```bash
gh repo clone YOUR-USERNAME/claude-h1ve ~/hive
~/hive/scripts/new-machine.sh your-machine-name
```

**Step 3:** Fill in your machine file:

```
~/hive/machines/your-machine-name/machine.md
```

Hardware, OS, installed tools, hook setup. See `machines/_example-linux/`,
`machines/_example-windows-wsl/`, or `machines/_example-windows-native/` for filled examples.
Then rebuild: `bash ~/hive/scripts/propagate.sh`

**Step 4:** Set up hooks so sessions auto-pull and auto-sync. See `templates/new-machine-setup.md` Step 5
for both Linux/WSL2 and native Windows variants.

Done. Every Claude Code session on this machine now reads from the hive and syncs on exit.

---

## Adding more machines

On each new machine:

```bash
gh repo clone YOUR-USERNAME/claude-h1ve ~/hive
~/hive/scripts/new-machine.sh machine-name
```

---

## Day-to-day

**Hooks handle it automatically** — if wired up, you don't need to run anything manually.

**Manual sync (mid-session or if hooks aren't set up):**
```bash
~/hive/scripts/sync.sh
```
Stashes local changes, pulls latest, restores, rebuilds CLAUDE.md files, commits with
hostname + timestamp, pushes. If a merge conflict is detected, halts with a clear error
and recovery instructions.

**After editing shared rules:**
```bash
~/hive/scripts/propagate.sh
```
Rebuilds `CLAUDE.md` for every machine from `machine.md` + `shared/CLAUDE-shared.md`.

---

## Repo structure

```
install.sh                    One-command installer (run after forking)
machines/                     Per-machine profiles
  _example-linux/             Reference: Linux setup
  _example-windows-wsl/       Reference: Windows + Claude Code in WSL2
  _example-windows-native/    Reference: Windows + Claude Code in Git Bash (native)
  <your-machine>/
    machine.md                Editable source — your specs and notes
    CLAUDE.md                 Generated artifact — never edit directly
memory/
  shared.md                   Cross-machine state
  projects.md                 Active work and what's next
  decisions.md                Architectural and workflow decisions
  kb.md                       Knowledge base — gotchas and fixes, strict schema
shared/
  CLAUDE-shared.md            Source of truth for shared rules across all machines
  settings.json               Hook config template (Linux / WSL2)
scripts/
  new-machine.sh              Create machine profile + symlink
  session-start.sh            Hook: pull hive once per session on first prompt
  sync.sh                     Hook: propagate + commit + push on session end
  propagate.sh                Build CLAUDE.md artifacts from source files
templates/
  machine-template.md         Blank machine.md to fill in
  new-machine-setup.md        Full manual setup guide (all platforms)
handoffs/                     Cross-agent delegation (Claude ↔ Gemini ↔ etc.)
  archive/                    Resolved handoffs — permanent record, never deleted
projects/                     Project-scoped CLAUDE.md files (symlinked into working dirs)
agents/
  claude/                     Claude Code conventions and constraints
  gemini/                     Gemini CLI — same pattern, uses GEMINI.md
```

---

## Cross-agent handoffs

When one agent hits a wall or needs a second opinion, it creates a handoff file in `handoffs/`.
The receiving agent reads it, responds, and moves it to `handoffs/archive/`.

Session start automatically scans `handoffs/` (root only — not archive) for open handoffs
addressed to the current agent.

See `handoffs/README.md` for the full protocol and `handoffs/template.md` to create one.

---

## Multi-agent support

Gemini CLI uses `GEMINI.md` the same way Claude uses `CLAUDE.md`. The `agents/gemini/`
directory documents how to wire it into the same hive. Same memory files, same sync
workflow, no conflicts.

See `agents/gemini/instructions.md` for setup.

---

## Contributing

Built because this pain is universal and the solution is obvious once you see it. PRs welcome.
