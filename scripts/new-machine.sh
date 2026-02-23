#!/bin/bash
# Sets up a new machine in the hive
# Usage: ./scripts/new-machine.sh <machine-name>
#
# Creates machines/<name>/machine.md from template, builds CLAUDE.md via
# propagate.sh, and symlinks ~/.claude/CLAUDE.md to the generated file.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$REPO_DIR/templates/machine-template.md"
MACHINE_NAME="${1:-}"

if [ -z "$MACHINE_NAME" ]; then
  echo "Usage: $0 <machine-name>"
  echo "Example: $0 my-laptop"
  exit 1
fi

MACHINE_DIR="$REPO_DIR/machines/$MACHINE_NAME"
MACHINE_FILE="$MACHINE_DIR/machine.md"
CLAUDE_FILE="$MACHINE_DIR/CLAUDE.md"
CLAUDE_CONFIG="$HOME/.claude/CLAUDE.md"

if [ -d "$MACHINE_DIR" ]; then
  echo "Machine '$MACHINE_NAME' already exists at $MACHINE_DIR"
  echo "To re-link the symlink: ln -sf $CLAUDE_FILE $CLAUDE_CONFIG"
  exit 1
fi

# Create machine.md from template
mkdir -p "$MACHINE_DIR"
cp "$TEMPLATE" "$MACHINE_FILE"
echo "Created: $MACHINE_FILE"

# Build CLAUDE.md artifact from machine.md + shared instructions
bash "$SCRIPT_DIR/propagate.sh"

# Symlink ~/.claude/CLAUDE.md → generated CLAUDE.md
# Back up existing file if it's not already a symlink
mkdir -p "$(dirname "$CLAUDE_CONFIG")"

if [ -f "$CLAUDE_CONFIG" ] && [ ! -L "$CLAUDE_CONFIG" ]; then
  BACKUP="${CLAUDE_CONFIG}.backup-$(date +%Y%m%d%H%M)"
  mv "$CLAUDE_CONFIG" "$BACKUP"
  echo "Backed up existing CLAUDE.md → $BACKUP"
fi

ln -sf "$CLAUDE_FILE" "$CLAUDE_CONFIG"

echo ""
echo "  Machine '$MACHINE_NAME' added to the hive."
echo ""
echo "  Source:  $MACHINE_FILE"
echo "  Built:   $CLAUDE_FILE"
echo "  Symlink: $CLAUDE_CONFIG → $CLAUDE_FILE"
echo ""
echo "  Next steps:"
echo "    1. Edit $MACHINE_FILE — fill in hardware, OS, tools, and hook setup"
echo "    2. Run scripts/propagate.sh to rebuild CLAUDE.md after editing"
echo "    3. Set up hooks — see templates/new-machine-setup.md Step 5"
echo "    4. Run scripts/sync.sh to push to the hive"
echo ""
