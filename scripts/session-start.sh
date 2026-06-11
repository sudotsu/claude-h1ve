#!/bin/bash
# h1ve session start — pull latest, surface previous sync failures, verify hook config
# Wired to SessionStart hook with matcher "startup|resume|clear"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"
SCRATCH="$REPO_ROOT/scratch"
STATUS_FILE="$SCRATCH/last-sync-status"

# 1. Pull latest — capture pre-pull HEAD so we can diff everything that changed
cd "$REPO_ROOT"
PRE_PULL=$(git rev-parse HEAD 2>/dev/null || echo "")
git pull --quiet 2>/dev/null || true
POST_PULL=$(git rev-parse HEAD 2>/dev/null || echo "")

# Surface what changed since this machine was last active (full repo, no path filter)
if [ -n "$PRE_PULL" ] && [ "$PRE_PULL" != "$POST_PULL" ]; then
  echo ""
  echo "=== H1VE: CHANGES SINCE LAST SESSION ==="
  echo "--- Commits ---"
  git log --oneline "$PRE_PULL..$POST_PULL"
  echo "--- Diff ---"
  git diff "$PRE_PULL..$POST_PULL"
  echo "========================================="
  echo ""
fi

# 2. Auto-repair if setup-machine.sh has changed since last run on this machine
# Skipped on Windows Git Bash (MSYSTEM is set there; Windows needs setup-machine.ps1)
if [ -z "${MSYSTEM:-}" ]; then
  SETUP_NAME_FILE="$SCRATCH/setup-machine-name"
  SETUP_COMMIT_FILE="$SCRATCH/setup-machine-commit"
  if [ -f "$SETUP_NAME_FILE" ] && [ -f "$SETUP_COMMIT_FILE" ]; then
    STORED_COMMIT=$(cat "$SETUP_COMMIT_FILE")
    CURRENT_COMMIT=$(git -C "$REPO_ROOT" log -1 --format="%H" -- scripts/setup-machine.sh 2>/dev/null)
    if [ "$STORED_COMMIT" != "$CURRENT_COMMIT" ]; then
      MACHINE_NAME=$(cat "$SETUP_NAME_FILE")
      echo ""
      echo "=== H1VE: setup-machine.sh changed — auto-repairing $MACHINE_NAME... ==="
      bash "$REPO_ROOT/scripts/setup-machine.sh" "$MACHINE_NAME"
      echo "========================================================================"
      echo ""
    fi
  elif [ ! -f "$SETUP_NAME_FILE" ]; then
    echo ""
    echo "=== H1VE: setup-machine.sh has never been run on this machine ==="
    echo "Run: bash ~/h1ve/scripts/setup-machine.sh"
    echo "=================================================================="
    echo ""
  fi
fi

# 3. Surface previous sync failure if any
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

# 4. Verify SessionEnd and PreCompact hooks — auto-repair if drifted
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
