#!/bin/bash
# Sets up a new machine in the hive
# Usage: ./scripts/new-machine.sh <machine-name>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$REPO_DIR/templates/machine-template.md"
SHARED="$REPO_DIR/shared/CLAUDE-shared.md"
MACHINE_NAME="${1:-}"

if [ -z "$MACHINE_NAME" ]; then
  echo "Usage: $0 <machine-name>"
  echo "Example: $0 my-laptop"
  exit 1
fi

MACHINE_DIR="$REPO_DIR/machines/$MACHINE_NAME"
MACHINE_FILE="$MACHINE_DIR/CLAUDE.md"
CLAUDE_CONFIG="$HOME/.claude/CLAUDE.md"

if [ -d "$MACHINE_DIR" ]; then
  echo "Machine '$MACHINE_NAME' already exists at $MACHINE_DIR"
  echo "To re-link the symlink: ln -sf $MACHINE_FILE $CLAUDE_CONFIG"
  exit 1
fi

# Create machine file from template + shared section
mkdir -p "$MACHINE_DIR"
cp "$TEMPLATE" "$MACHINE_FILE"

printf '\n---\n<!-- SHARED — synced from ~/hive/shared/CLAUDE-shared.md -->\n\n' >> "$MACHINE_FILE"
cat "$SHARED" >> "$MACHINE_FILE"

# Set up symlink — back up existing CLAUDE.md if it's a real file (not already a symlink)
mkdir -p "$(dirname "$CLAUDE_CONFIG")"

if [ -f "$CLAUDE_CONFIG" ] && [ ! -L "$CLAUDE_CONFIG" ]; then
  BACKUP="${CLAUDE_CONFIG}.backup-$(date +%Y%m%d%H%M)"
  mv "$CLAUDE_CONFIG" "$BACKUP"
  echo "Backed up existing CLAUDE.md → $BACKUP"
fi

ln -sf "$MACHINE_FILE" "$CLAUDE_CONFIG"

echo ""
echo "  Machine '$MACHINE_NAME' added to the hive."
echo ""
echo "  File:    $MACHINE_FILE"
echo "  Symlink: $CLAUDE_CONFIG → $MACHINE_FILE"
echo ""
echo "  Next:"
echo "    1. Edit $MACHINE_FILE — fill in your hardware, OS, and tools"
echo "    2. Run scripts/sync.sh to push to the hive"
echo ""
