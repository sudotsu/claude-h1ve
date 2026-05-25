# Handoffs

Asynchronous handoff protocol between AI agents. When one agent hits a wall, needs a second opinion, or wants to delegate to a better-suited model, it creates a handoff file here.

## Filename Convention
```
YYYY-MM-DD-HHMM-<from>-to-<to>-<slug>.md
```
Example: `2026-02-21-1430-claude-to-gemini-wsl-browser-fix.md`

## How to Create a Handoff

1. Copy `template.md` to a new file using the naming convention above
2. Fill in ALL four sections — Problem, Context, Attempted Solutions, Required Output
3. Do not leave any section blank. If nothing was attempted, write "None — delegating before attempting."
4. Set **Status: open**
5. Sync: `bash ~/h1ve/scripts/sync.sh`

## How to Respond to a Handoff

1. Find open handoffs directed at you in the **root** `handoffs/` directory
2. Set **Status: in-progress** while working
3. Fill in the Response section completely
4. Set **Status: resolved** when done
5. Move the file to `handoffs/archive/` immediately
6. Sync

## Rules

- **Use the template exactly.** No free-form files. The four sections are mandatory.
- **Resolved handoffs are never deleted — move them to `handoffs/archive/` immediately upon resolution.** They are a permanent record of cross-agent collaboration.
- **One problem per file.** If you have two problems, create two handoffs.
- **Required Output must be unambiguous.** If the receiving agent has to guess what format or scope you want, rewrite it.

## Session Start Check

On session start, agents scan **only the root `handoffs/` directory** for open handoffs addressed to them. Do not read `handoffs/archive/` — that directory is historical record only. Only read it when explicitly searching for past context.

## Agents

| Agent | Handles |
|-------|---------|
| claude | Systems work, code architecture, file ops, Claude Code tooling |
| gemini | Code review, second opinions, research, tasks Claude gets stuck on |
| chatgpt | (TBD) |
