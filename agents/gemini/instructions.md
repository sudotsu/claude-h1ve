# Gemini Agent

Gemini CLI follows the same hive pattern as Claude — different file name, same idea.

## How it hooks into the hive

Gemini CLI loads `~/.gemini/GEMINI.md` (or `GEMINI.md` in the project root, depending
on version) as its global instructions. Wire it in the same way as Claude:

```bash
# Create your Gemini machine file
cp ~/hive/templates/machine-template.md ~/hive/machines/<your-machine>/GEMINI.md
# Edit it — fill in your machine specs, append shared/CLAUDE-shared.md at the bottom

# Symlink
mkdir -p ~/.gemini
ln -sf ~/hive/machines/<your-machine>/GEMINI.md ~/.gemini/GEMINI.md
```

> **Check your version first:** Run `gemini --help` or check the Gemini CLI docs to confirm
> the exact config file path for your installed version before symlinking.

## Shared memory

Gemini reads the same `memory/` files as Claude. Update them the same way at session end,
then run `scripts/sync.sh`. Both agents stay current.

## Notes
- Keep Gemini-specific instructions in `GEMINI.md`, Claude-specific in `CLAUDE.md`
- The shared rules section (`CLAUDE-shared.md`) can be appended to both — same preferences,
  same session protocol, no reason to diverge
- Agents don't modify each other's config files
