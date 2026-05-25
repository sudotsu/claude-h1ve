#!/bin/bash
# h1ve machine setup — wire ~/.claude/settings.json hooks and CLAUDE.md symlink
# Idempotent: safe to run multiple times. Merges hooks without overwriting other settings.
# For Windows machines use scripts/setup-machine.ps1 instead.
#
# Usage:
#   bash ~/h1ve/scripts/setup-machine.sh <machine-name>
#   bash ~/h1ve/scripts/setup-machine.sh          (lists profiles and prompts)

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
MACHINE_NAME="${1:-}"

# List available machines if no name provided
if [ -z "$MACHINE_NAME" ]; then
  echo "Available machine profiles:"
  for d in "$REPO_ROOT/machines"/*/; do
    echo "  $(basename "$d")"
  done
  echo ""
  printf "Machine name: "
  read -r MACHINE_NAME
fi

MACHINE_DIR="$REPO_ROOT/machines/$MACHINE_NAME"
MACHINE_FILE="$MACHINE_DIR/machine.md"
CLAUDE_MD="$MACHINE_DIR/CLAUDE.md"

# Validate
if [ ! -d "$MACHINE_DIR" ]; then
  echo "ERROR: No profile found at machines/$MACHINE_NAME/"
  echo "Create it first:"
  echo "  mkdir -p $REPO_ROOT/machines/$MACHINE_NAME"
  echo "  cp $REPO_ROOT/templates/machine-template.md $REPO_ROOT/machines/$MACHINE_NAME/machine.md"
  exit 1
fi

if [ ! -f "$MACHINE_FILE" ]; then
  echo "ERROR: $MACHINE_FILE not found. Fill in machine.md before running setup."
  exit 1
fi

echo ""
echo "Setting up: $MACHINE_NAME"
echo "Repo root:  $REPO_ROOT"
echo "Home:       $HOME"
echo ""

# 1. Build CLAUDE.md if it doesn't exist yet
if [ ! -f "$CLAUDE_MD" ]; then
  echo "[1/4] Building CLAUDE.md..."
  bash "$REPO_ROOT/scripts/propagate.sh" > /dev/null
  echo "  Built"
else
  echo "[1/4] CLAUDE.md already exists — skipping rebuild"
fi

# 2. Symlink CLAUDE.md
echo "[2/4] Wiring ~/.claude/CLAUDE.md symlink..."
mkdir -p "$CLAUDE_DIR"
ln -sf "$CLAUDE_MD" "$CLAUDE_DIR/CLAUDE.md"
echo "  Linked"

# 3. Merge h1ve hooks into ~/.claude/settings.json
echo "[3/4] Merging h1ve hooks into ~/.claude/settings.json..."
python3 - "$CLAUDE_DIR/settings.json" << 'PYEOF'
import json, sys, os

settings_path = sys.argv[1]

settings = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)

hooks = settings.setdefault('hooks', {})

session_start_cmd = "bash -c '$HOME/h1ve/scripts/session-start.sh'"
sync_cmd          = "bash -c '$HOME/h1ve/scripts/sync.sh'"

def hook_present(event, needle):
    return any(
        any(needle in h.get('command', '') for h in entry.get('hooks', []))
        for entry in hooks.get(event, [])
    )

changes = []

if not hook_present('SessionStart', 'session-start.sh'):
    hooks['SessionStart'] = [{"matcher": "startup|resume|clear", "hooks": [
        {"type": "command", "command": session_start_cmd, "timeout": 15}
    ]}]
    changes.append('SessionStart')

if not hook_present('SessionEnd', 'sync.sh'):
    hooks['SessionEnd'] = [{"hooks": [{"type": "command", "command": sync_cmd, "timeout": 30}]}]
    changes.append('SessionEnd')

if not hook_present('PreCompact', 'sync.sh'):
    hooks['PreCompact'] = [{"hooks": [{"type": "command", "command": sync_cmd, "timeout": 30}]}]
    changes.append('PreCompact')

if 'autoMemoryDirectory' not in settings:
    settings['autoMemoryDirectory'] = '~/h1ve/memory/claude'
    changes.append('autoMemoryDirectory')

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

if changes:
    print(f"  Added: {', '.join(changes)}")
else:
    print("  All hooks already present — no changes made")
PYEOF

# 4. Verify
echo "[4/4] Verifying..."
ERRORS=0

# Symlink check
if [ -L "$CLAUDE_DIR/CLAUDE.md" ] && [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  echo "  OK    ~/.claude/CLAUDE.md → $CLAUDE_MD"
else
  echo "  FAIL  ~/.claude/CLAUDE.md symlink broken or missing"
  ERRORS=$((ERRORS + 1))
fi

# Hook check
python3 - "$CLAUDE_DIR/settings.json" << 'PYEOF'
import json, sys

settings_path = sys.argv[1]
errors = 0

with open(settings_path) as f:
    s = json.load(f)

hooks = s.get('hooks', {})
checks = [
    ('SessionStart', 'session-start.sh'),
    ('SessionEnd',   'sync.sh'),
    ('PreCompact',   'sync.sh'),
]

for event, needle in checks:
    found = any(
        any(needle in h.get('command', '') for h in entry.get('hooks', []))
        for entry in hooks.get(event, [])
    )
    print(f"  {'OK  ' if found else 'FAIL'}  {event} ({needle})")
    if not found:
        errors += 1

sys.exit(errors)
PYEOF
HOOK_EXIT=$?
ERRORS=$((ERRORS + HOOK_EXIT))

echo ""
if [ $ERRORS -eq 0 ]; then
  echo "Setup complete. $MACHINE_NAME is ready."
  echo "Start a Claude Code session to verify hooks fire."
else
  echo "Setup finished with $ERRORS error(s). Review output above."
  exit 1
fi
