# Claude Agent

Claude Code is the primary coding, architecture, and systems agent in this hive.

## Role
- Code, debugging, refactoring, architecture
- System administration and configuration
- Hardware diagnostics and optimization
- Security tooling and research

## How it hooks into the hive

Claude Code loads `~/.claude/CLAUDE.md` as global instructions at session start.
That file is symlinked to `~/hive/machines/<this-machine>/CLAUDE.md` — a generated
artifact built from two sources:

```
machines/<name>/machine.md  ──┐
                               ├──▶ propagate.sh ──▶ machines/<name>/CLAUDE.md
shared/CLAUDE-shared.md    ──┘                              │
                                                         symlink
                                                            │
                                                   ~/.claude/CLAUDE.md
```

Two hooks automate the session lifecycle:
- **UserPromptSubmit** → `session-start.sh` — pulls the hive once per session (PPID lockfile)
- **Stop** → `sync.sh` — rebuilds CLAUDE.md files, commits changes, pushes

## File edit constraints

**machines/<name>/CLAUDE.md is a generated artifact — never edit it directly.**
- To update machine specs, paths, or tools: edit `machines/<name>/machine.md`
- To update shared rules: edit `shared/CLAUDE-shared.md`
- Run `scripts/propagate.sh` to rebuild after editing either source
- The warning banner at line 1 of each CLAUDE.md is there for exactly this reason
- Direct edits to CLAUDE.md are silently destroyed on the next propagate run

## Session behavior

Defined in `shared/CLAUDE-shared.md` under **Hive Session Protocol**:
- Pulls latest on first prompt (via hook)
- Reads memory files at session start
- Scans root `handoffs/` for open handoffs addressed to claude
- Updates memory files at session end
- Sync runs automatically via Stop hook

## Handoffs

When Claude needs a second opinion or hits a wall, it creates a handoff in `handoffs/`
addressed to the appropriate agent. See `handoffs/README.md` for the full protocol.
Resolved handoffs move to `handoffs/archive/` immediately — never deleted, never read passively.

## Conventions
- Direct, no fluff
- Prefer practical over theoretical
- Don't over-engineer
- When in doubt, ask
