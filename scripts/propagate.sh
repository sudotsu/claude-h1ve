#!/bin/bash
# Builds each machine's CLAUDE.md from two sources:
#   machines/<name>/machine.md  — machine-specific content (human/agent editable)
#   shared/CLAUDE-shared.md     — shared rules for all machines
#
# CLAUDE.md is a generated build artifact. Never edit it directly.
# To change machine specs: edit machine.md
# To change shared rules: edit shared/CLAUDE-shared.md
# Then run this script (or let sync.sh call it automatically).

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHARED_FILE="$REPO_ROOT/shared/CLAUDE-shared.md"

if [ ! -f "$SHARED_FILE" ]; then
  echo "ERROR: $SHARED_FILE not found"
  exit 1
fi

# Extract shared content: everything after the first --- in CLAUDE-shared.md (skips preamble)
SHARED_CONTENT=$(sed -n '/^---$/,$ p' "$SHARED_FILE" | tail -n +2)

BUILT=0
SKIPPED=0

for MACHINE_DIR in "$REPO_ROOT"/machines/*/; do
  MACHINE_NAME=$(basename "$MACHINE_DIR")
  MACHINE_FILE="$MACHINE_DIR/machine.md"
  CLAUDE_FILE="$MACHINE_DIR/CLAUDE.md"

  if [ ! -f "$MACHINE_FILE" ]; then
    echo "SKIP: $MACHINE_FILE does not exist"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  MACHINE_CONTENT=$(cat "$MACHINE_FILE")
  BANNER="<!-- AUTO-GENERATED FILE — DO NOT EDIT DIRECTLY. Source: machines/${MACHINE_NAME}/machine.md + shared/CLAUDE-shared.md. Run scripts/propagate.sh to rebuild. -->"

  printf '%s\n\n%s\n\n---\n<!-- SHARED — synced from ~/hive/shared/CLAUDE-shared.md -->\n\n%s\n' \
    "$BANNER" \
    "$MACHINE_CONTENT" \
    "$SHARED_CONTENT" > "$CLAUDE_FILE"

  echo "BUILT: $CLAUDE_FILE"
  BUILT=$((BUILT + 1))
done

echo ""
echo "Done. $BUILT built, $SKIPPED skipped."
