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

# 3. Enforce desired h1ve hook state in ~/.claude/settings.json
echo "[3/4] Enforcing h1ve hook state in ~/.claude/settings.json..."
python3 - "$CLAUDE_DIR/settings.json" << 'PYEOF'
import json, sys, os

settings_path = sys.argv[1]

settings = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)

hooks = settings.setdefault('hooks', {})

H1VE = 'h1ve/scripts/'

# Complete desired h1ve hook spec — single source of truth
DESIRED = {
    'SessionStart': {
        'needle': 'session-start.sh',
        'entry': {"matcher": "startup|resume|clear", "hooks": [
            {"type": "command", "command": "bash -c '$HOME/h1ve/scripts/session-start.sh'", "timeout": 15}
        ]}
    },
    'SessionEnd': {
        'needle': 'sync.sh',
        'entry': {"hooks": [{"type": "command", "command": "bash -c '$HOME/h1ve/scripts/sync.sh'", "timeout": 30}]}
    },
    'PreCompact': {
        'needle': 'sync.sh',
        'entry': {"hooks": [{"type": "command", "command": "bash -c '$HOME/h1ve/scripts/sync.sh'", "timeout": 30}]}
    },
    'PostToolUse': {
        'needle': 'semgrep-scan.sh',
        'entry': {"matcher": "Edit|Write", "hooks": [
            {"type": "command", "command": "bash -c '$HOME/h1ve/scripts/semgrep-scan.sh'", "timeout": 30}
        ]}
    },
}

removed = []
added = []

# Remove stale h1ve hooks from every event (owns its namespace, leaves non-h1ve entries alone)
for event in list(hooks.keys()):
    desired_needle = DESIRED.get(event, {}).get('needle', '')
    cleaned = []
    for entry in hooks[event]:
        cmds = [h.get('command', '') for h in entry.get('hooks', [])]
        is_h1ve = any(H1VE in cmd for cmd in cmds)
        is_correct = desired_needle and any(desired_needle in cmd for cmd in cmds)
        if is_h1ve and not is_correct:
            labels = [cmd.split('/')[-1] for cmd in cmds if H1VE in cmd]
            removed.append(f"{event}({','.join(labels)})")
        else:
            cleaned.append(entry)
    if cleaned:
        hooks[event] = cleaned
    else:
        del hooks[event]

# Add any missing desired hooks
for event, spec in DESIRED.items():
    present = any(
        any(spec['needle'] in h.get('command', '') for h in entry.get('hooks', []))
        for entry in hooks.get(event, [])
    )
    if not present:
        hooks.setdefault(event, []).append(spec['entry'])
        added.append(event)

if 'autoMemoryDirectory' not in settings:
    settings['autoMemoryDirectory'] = '~/h1ve/memory/claude'
    added.append('autoMemoryDirectory')

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

if removed:
    print(f"  Removed stale: {', '.join(removed)}")
if added:
    print(f"  Added: {', '.join(added)}")
if not removed and not added:
    print("  Already at desired state — no changes made")
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
    ('PostToolUse',  'semgrep-scan.sh'),
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
  # Record machine identity and script version for session-start self-check
  mkdir -p "$REPO_ROOT/scratch"
  echo "$MACHINE_NAME" > "$REPO_ROOT/scratch/setup-machine-name"
  git -C "$REPO_ROOT" log -1 --format="%H" -- scripts/setup-machine.sh > "$REPO_ROOT/scratch/setup-machine-commit"
else
  echo "Setup finished with $ERRORS error(s). Review output above."
  exit 1
fi
