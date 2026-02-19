# Claude Agent

Claude Code is the primary coding, architecture, and systems agent in this hive.

## Role
- Code, debugging, refactoring, architecture
- System administration and configuration
- Hardware diagnostics and optimization
- Security tooling and research

## How it hooks into the hive

Claude Code loads `~/.claude/CLAUDE.md` as global instructions at session start.
That file is symlinked to `~/hive/machines/<this-machine>/CLAUDE.md` — so Claude
always reads from the repo automatically. No manual steps per session.

## Session behavior

Defined in `shared/CLAUDE-shared.md` under **Hive Session Protocol** — reads memory
files at start, updates them at end, runs sync.sh before closing.

## Notes
- Machine-specific context (hardware, tools, paths) is in the top half of each machine file
- Shared rules (preferences, engineering standards, protocol) are in the bottom half
- The `<!-- SHARED -->` marker separates them — `propagate.sh` uses it as the cut point
