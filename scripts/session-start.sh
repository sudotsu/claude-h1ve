#!/bin/bash
# h1ve session start — pull latest, surface previous sync failures, verify hook config
# Wired to SessionStart hook with matcher "startup|resume|clear"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"
SCRATCH="$REPO_ROOT/scratch"
STATUS_FILE="$SCRATCH/last-sync-status"

# 1. Pull latest
cd "$REPO_ROOT" && git pull --quiet 2>/dev/null || true

# 2. Surface previous sync failure if any
if [ -f "$STATUS_FILE" ]; then
  STATUS_FIRST=$(head -1 "$STATUS_FILE")
  if [[ "$STATUS_FIRST" == FAILED* ]]; then
    echo ""
    echo "=== H1VE: PREVIOUS SYNC FAILED ==="
    cat "$STATUS_FILE"
    echo ""
    echo "Fix then run: bash ~/h1ve/scripts/sync.sh"
    echo "==================================="
    echo ""
  fi
fi

# 3. Verify SessionEnd and PreCompact hooks — auto-repair if drifted
# Skipped on Windows Git Bash (MSYSTEM is set there; Windows needs setup-machine.ps1)
if [ -f "$SETTINGS" ] && [ -z "${MSYSTEM:-}" ]; then
  python3 - "$SETTINGS" << 'PYEOF'
import json, sys, os

settings_path = sys.argv[1]

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})
sync_cmd = "bash -c '$HOME/h1ve/scripts/sync.sh'"
missing = []

for event in ('SessionEnd', 'PreCompact'):
    found = any(
        any(h.get('command') == sync_cmd for h in entry.get('hooks', []))
        for entry in hooks.get(event, [])
    )
    if not found:
        missing.append(event)

if missing:
    for event in missing:
        hooks[event] = [{"hooks": [{"type": "command", "command": sync_cmd, "timeout": 30}]}]
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
    print(f"\n=== H1VE: Hook drift detected — restored {', '.join(missing)} in settings.json ===\n")
PYEOF
fi
