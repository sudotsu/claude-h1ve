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
# Parse args: separate flags from positional machine name
AUTO_DETECT=false
MACHINE_NAME=""
for arg in "$@"; do
  case "$arg" in
    --auto-detect) AUTO_DETECT=true ;;
    --*) echo "Unknown flag: $arg"; exit 1 ;;
    *) MACHINE_NAME="$arg" ;;
  esac
done

# Prompt if no machine name provided
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
  if [ "$AUTO_DETECT" = true ]; then
    mkdir -p "$MACHINE_DIR"
  else
    echo "ERROR: No profile found at machines/$MACHINE_NAME/"
    echo "Create it first, or use --auto-detect to generate machine.md automatically:"
    echo "  bash ~/h1ve/scripts/setup-machine.sh --auto-detect $MACHINE_NAME"
    exit 1
  fi
fi

if [ ! -f "$MACHINE_FILE" ] && [ "$AUTO_DETECT" = false ]; then
  echo "ERROR: $MACHINE_FILE not found."
  echo "Use --auto-detect to generate it automatically, or fill in the template manually:"
  echo "  bash ~/h1ve/scripts/setup-machine.sh --auto-detect $MACHINE_NAME"
  exit 1
fi

echo ""
echo "Setting up: $MACHINE_NAME"
echo "Repo root:  $REPO_ROOT"
echo "Home:       $HOME"
echo ""

# 0. Auto-detect hardware and pre-populate machine.md if requested
if [ "$AUTO_DETECT" = true ]; then
  echo "[0/4] Auto-detecting hardware specs..."
  mkdir -p "$MACHINE_DIR"
  if [ -f "$MACHINE_FILE" ]; then
    echo "  machine.md already exists — skipping auto-detect (delete it first to re-detect)"
  else
    # Detect whether we're in WSL
    IS_WSL=false
    grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true

    # CPU
    CPU=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | sed 's/.*: //' || echo "unknown")
    CORES=$(nproc 2>/dev/null || echo "?")

    # RAM
    RAM=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "unknown")

    # Storage
    STORAGE=$(lsblk -d -o NAME,SIZE,MODEL,TYPE 2>/dev/null | grep -i disk | head -5 || echo "unknown")

    # OS
    OS=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -s)
    KERNEL=$(uname -r)

    # Tools
    NODE_VER=$(node -v 2>/dev/null || echo "not installed")
    PYTHON_VER=$(python3 --version 2>/dev/null || echo "not installed")
    GIT_VER=$(git --version 2>/dev/null | cut -d\  -f3 || echo "not installed")
    GH_VER=$(gh --version 2>/dev/null | head -1 | cut -d\  -f3 || echo "not installed")
    CLAUDE_VER=$(claude --version 2>/dev/null | head -1 || echo "not installed")

    # Windows hardware via PowerShell (WSL only)
    WIN_CPU=""
    WIN_RAM=""
    WIN_GPU=""
    WIN_MB=""
    if [ "$IS_WSL" = true ] && command -v powershell.exe &>/dev/null; then
      WIN_CPU=$(powershell.exe -NoProfile -Command "Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name" 2>/dev/null | tr -d '\r' || echo "")
      WIN_RAM=$(powershell.exe -NoProfile -Command "(Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB" 2>/dev/null | tr -d '\r' | xargs printf "%.0fGB" 2>/dev/null || echo "")
      # Prefer discrete GPU (NVIDIA/AMD) over integrated Intel
      WIN_GPU=$(powershell.exe -NoProfile -Command "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name" 2>/dev/null | tr -d '\r' | grep -v "Microsoft\|Basic\|^$" | grep -i "nvidia\|amd\|radeon" | head -1 || echo "")
      # Fall back to any non-Microsoft controller if no discrete found
      [ -z "$WIN_GPU" ] && WIN_GPU=$(powershell.exe -NoProfile -Command "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name" 2>/dev/null | tr -d '\r' | grep -v "Microsoft\|Basic\|^$" | head -1 || echo "")
      WIN_MB=$(powershell.exe -NoProfile -Command "Get-CimInstance Win32_BaseBoard | Select-Object -ExpandProperty Product" 2>/dev/null | tr -d '\r' || echo "")
      [ -n "$WIN_CPU" ] && CPU="$WIN_CPU"
      [ -n "$WIN_RAM" ] && RAM="$WIN_RAM"
    fi

    GPU_LINE=""
    if [ -n "$WIN_GPU" ]; then
      GPU_LINE="- **GPU**: $WIN_GPU"
    else
      GPU_RAW=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" | head -2 | sed 's/.*: //')
      [ -n "$GPU_RAW" ] && GPU_LINE="- **GPU**: $GPU_RAW"
    fi

    WSL_NOTE=""
    [ "$IS_WSL" = true ] && WSL_NOTE="
## WSL-Specific Notes
- Running inside WSL2 $(uname -r | grep -oP 'microsoft.*' || echo "")
- Home dir is \`/home/$(whoami)/\`, not \`/mnt/c/Users/...\`"

    # Title-case the machine name for the heading
    TITLE=$(echo "$MACHINE_NAME" | tr '-' ' ' | sed 's/\b./\u&/g' 2>/dev/null || echo "$MACHINE_NAME")

    {
      echo "# ${TITLE} — Claude Instructions"
      echo ""
      echo "## Machine"
      echo "- **CPU**: $CPU ($CORES cores/threads)"
      echo "- **RAM**: $RAM"
      [ -n "$GPU_LINE" ] && echo "$GPU_LINE"
      echo "- **Storage**:"
      echo "$STORAGE" | while IFS= read -r line; do [ -n "$line" ] && echo "  - $line"; done
      echo "- **Role**: TODO — describe primary use (dev/gaming/mobile/etc.)"
      echo ""
      echo "## OS"
      echo "- **Primary**: $OS"
      echo "- **Kernel**: $KERNEL"
      [ "$IS_WSL" = true ] && printf "\n## WSL-Specific Notes\n- Running inside WSL2\n- Home dir is \`/home/$(whoami)/\`, not \`/mnt/c/Users/...\`\n"
      echo ""
      echo "## Tools Installed"
      echo "- **Node.js**: $NODE_VER"
      echo "- **Python**: $PYTHON_VER"
      echo "- **Git**: $GIT_VER"
      echo "- **gh**: $GH_VER"
      echo "- **Claude Code**: $CLAUDE_VER"
      echo ""
      echo "## Important Paths"
      echo "- H1VE repo: \`~/h1ve/\`"
      echo "- Claude config: \`~/.claude/\` (CLAUDE.md symlinked to machines/$MACHINE_NAME/CLAUDE.md)"
      echo ""
      echo "## System Optimizations Applied"
      echo "- TODO: document optimizations after running optimization sweep"
      echo ""
      echo "## TODO"
      echo "- [ ] Fill in Role above"
      echo "- [ ] Run optimization sweep and update this file"
    } > "$MACHINE_FILE" 
    echo "  Created machine.md with detected specs — review and fill in TODOs before continuing"
    echo "  Edit: $MACHINE_FILE"
    echo ""
  fi
fi

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
python3 - "$CLAUDE_DIR/settings.json" "$REPO_ROOT" << 'PYEOF'
import json, sys, os

settings_path = sys.argv[1]
repo_root = sys.argv[2]

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
            {"type": "command", "command": f"bash -c '{repo_root}/scripts/session-start.sh'", "timeout": 15}
        ]}
    },
    'SessionEnd': {
        'needle': 'sync.sh',
        'entry': {"hooks": [{"type": "command", "command": f"bash -c '{repo_root}/scripts/sync.sh'", "timeout": 30}]}
    },
    'PreCompact': {
        'needle': 'sync.sh',
        'entry': {"hooks": [{"type": "command", "command": f"bash -c '{repo_root}/scripts/sync.sh'", "timeout": 30}]}
    },
    'PostToolUse': {
        'needle': 'semgrep-scan.sh',
        'entry': {"matcher": "Edit|Write", "hooks": [
            {"type": "command", "command": f"bash -c '{repo_root}/scripts/semgrep-scan.sh'", "timeout": 30}
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
