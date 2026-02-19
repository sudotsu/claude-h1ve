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

## System Notes
- Firewall active, DNS-over-TLS configured
```

```
# memory/projects.md

## api-refactor
- Status: in progress
- Last worked on: laptop, 2025-01-14
- Done: JWT access tokens working
- Next: refresh token rotation
```

```
# shared/CLAUDE-shared.md (appended to every machine file)

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

You finish a session on your laptop, run `sync.sh`. Tomorrow you sit down at your desktop.
Claude has already read the updated memory files. It knows what's done and what's next —
without you saying a word.

```
~/hive/scripts/sync.sh
# Commits: "sync: laptop 2025-01-14-2243"
# Pushes to GitHub

# Next day, desktop:
~/hive/scripts/sync.sh
# Pulls latest — desktop Claude now knows everything laptop Claude knew
```

---

## How it works

Claude Code loads `~/.claude/CLAUDE.md` as global instructions at the start of every session. claude-h1ve replaces that file with a symlink into this repo:

```
~/.claude/CLAUDE.md
        │
        └──symlink──▶  ~/hive/machines/your-machine/CLAUDE.md
                                │
                                └── shared rules from
                                    ~/hive/shared/CLAUDE-shared.md
                                    (propagated by scripts/propagate.sh)
```

Each machine has its own file: hardware specs, installed tools, OS-specific notes. Shared rules — your preferences, engineering standards, session protocol — live in one place and push to every machine file with one command.

Memory files capture what matters between sessions: what's set up where, active projects, decisions made. Every Claude instance reads them on start. The hive stays current.

---

## What this is not

- Not a prompt hack or "make AI smarter" trick
- Not a cloud service or third-party dependency
- Not project-specific — this is global, persistent infrastructure for your AI workflow

---

## Install

**Requires:** [Claude Code](https://claude.ai/code) · [GitHub CLI](https://cli.github.com/) · git

**Step 1:** Click **"Use this template"** → **"Create a new repository"** (top right of this page). Name it `claude-h1ve`, set visibility to your preference.

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
~/hive/machines/your-machine-name/CLAUDE.md
```

Hardware, OS, installed tools. The shared section is already appended. See `machines/_example-linux/` or `machines/_example-windows/` for reference.

Done. Every Claude Code session on this machine now reads from the hive.

---

## Adding more machines

On each new machine:

```bash
gh repo clone YOUR-USERNAME/claude-h1ve ~/hive
~/hive/scripts/new-machine.sh machine-name
```

---

## Day-to-day

**End of session — sync everything:**
```bash
~/hive/scripts/sync.sh
```
Commits any updates with hostname + timestamp. Pushes. Every other machine gets it on next pull.

**Updated shared rules — push to all machines:**
```bash
~/hive/scripts/propagate.sh
```
Rewrites the shared section of every machine CLAUDE.md from `shared/CLAUDE-shared.md`.

---

## Repo structure

```
install.sh              One-command installer (run after forking)
machines/               Per-machine CLAUDE.md files
  _example-linux/       Reference: Linux / WSL setup
  _example-windows/     Reference: Windows setup
memory/
  shared.md             Cross-machine state (what's set up where)
  projects.md           Active work and what's next
  decisions.md          Architectural and workflow decisions
shared/
  CLAUDE-shared.md      Source of truth for rules shared across all machines
scripts/
  new-machine.sh        Automate new machine setup + symlink
  sync.sh               Pull → commit → push
  propagate.sh          Push shared rules to all machine CLAUDE.md files
templates/
  machine-template.md   Blank machine file to fill in
agents/
  claude/               Claude Code config notes
  gemini/               Gemini CLI — same pattern, uses GEMINI.md
```

---

## Memory files

Claude reads these at the start of every session (as instructed in `CLAUDE-shared.md`). Keep them current.

| File | What goes here |
|---|---|
| `memory/shared.md` | Which machines are set up, key cross-machine decisions |
| `memory/projects.md` | Active projects, status, what's next |
| `memory/decisions.md` | Architectural and workflow decisions — so future sessions don't re-debate settled questions |

---

## Multi-agent support

Gemini CLI uses `GEMINI.md` the same way Claude uses `CLAUDE.md`. The `agents/gemini/` directory documents how to wire it into the same hive. Same memory files, same sync workflow, no conflicts.

See `agents/gemini/instructions.md` for setup.

---

## Contributing

Built because this pain is universal and the solution is obvious once you see it. PRs welcome.
