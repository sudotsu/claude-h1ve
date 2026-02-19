#!/bin/bash
# Propagates shared/CLAUDE-shared.md to all machine CLAUDE.md files
# Replaces everything after the <!-- SHARED --> marker in each file
#
# Run this whenever you update shared/CLAUDE-shared.md

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SHARED_FILE="$REPO_DIR/shared/CLAUDE-shared.md"
MACHINES_DIR="$REPO_DIR/machines"

if [ ! -f "$SHARED_FILE" ]; then
  echo "Error: shared/CLAUDE-shared.md not found"
  exit 1
fi

SHARED_CONTENT=$(cat "$SHARED_FILE")
COUNT=0

for machine_file in "$MACHINES_DIR"/*/CLAUDE.md; do
  [ -f "$machine_file" ] || continue

  MACHINE=$(basename "$(dirname "$machine_file")")

  # Skip example machines
  [[ "$MACHINE" == _example* ]] && continue

  if ! grep -q "<!-- SHARED" "$machine_file"; then
    echo "  Skipping $MACHINE — no <!-- SHARED --> marker found"
    continue
  fi

  # Keep everything up to and including the <!-- SHARED --> line
  BEFORE=$(awk '/<!-- SHARED/{print; exit} {print}' "$machine_file")

  # Write: before marker + blank line + shared content
  printf '%s\n\n%s\n' "$BEFORE" "$SHARED_CONTENT" > "$machine_file"

  echo "  Updated: $MACHINE"
  COUNT=$((COUNT + 1))
done

echo ""
echo "$COUNT machine file(s) updated."
echo "Run scripts/sync.sh to commit and push."
