#!/bin/bash
# Builds each machine's context files (CLAUDE.md and GEMINI.md) from three sources:
#   machines/<name>/machine.md    — machine-specific content (human/agent editable)
#   shared/CLAUDE-system.md       — h1ve infrastructure rules (session protocol, build rules, etc.)
#   shared/CLAUDE-behavior.md     — behavior, collaboration, and engineering standards
#   shared/GEMINI-shared.md       — Gemini-specific protocol (prepended before system+behavior)
#
# Foundation files are generated build artifacts. Never edit them directly.
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_SYSTEM="$REPO_ROOT/shared/CLAUDE-system.md"
CLAUDE_BEHAVIOR="$REPO_ROOT/shared/CLAUDE-behavior.md"
GEMINI_SHARED="$REPO_ROOT/shared/GEMINI-shared.md"

# Verify sources
for f in "$CLAUDE_SYSTEM" "$CLAUDE_BEHAVIOR" "$GEMINI_SHARED"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: $f not found"
    exit 1
  fi
done

# Extract shared content (everything after <!-- BEGIN SHARED --> marker)
MARKER="<!-- BEGIN SHARED -->"

extract_shared() {
  local file="$1"
  local line
  line=$(grep -n "^${MARKER}$" "$file" | cut -d: -f1)
  if [ -z "$line" ]; then
    echo "ERROR: ${MARKER} not found in $file" >&2
    exit 1
  fi
  tail -n +"$((line + 1))" "$file"
}

SYSTEM_CONTENT=$(extract_shared "$CLAUDE_SYSTEM")
BEHAVIOR_CONTENT=$(extract_shared "$CLAUDE_BEHAVIOR")
GEMINI_CONTENT=$(extract_shared "$GEMINI_SHARED")

BUILT=0
SKIPPED=0

for MACHINE_DIR in "$REPO_ROOT"/machines/*/; do
  MACHINE_NAME=$(basename "$MACHINE_DIR")
  MACHINE_FILE="$MACHINE_DIR/machine.md"

  if [ ! -f "$MACHINE_FILE" ]; then
    echo "SKIP: $MACHINE_FILE does not exist"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  MACHINE_CONTENT=$(cat "$MACHINE_FILE")
  BANNER="<!-- AUTO-GENERATED FILE — DO NOT EDIT DIRECTLY. Source: machines/${MACHINE_NAME}/machine.md + shared/CLAUDE-system.md + shared/CLAUDE-behavior.md. Run scripts/propagate.sh to rebuild. -->"

  # Build CLAUDE.md: machine + system + behavior
  printf '%s\n\n%s\n\n---\n<!-- SHARED — synced from ~/h1ve/shared/CLAUDE-system.md + CLAUDE-behavior.md -->\n\n%s\n\n%s\n' \
    "$BANNER" \
    "$MACHINE_CONTENT" \
    "$SYSTEM_CONTENT" \
    "$BEHAVIOR_CONTENT" > "${MACHINE_DIR}CLAUDE.md"

  # Build GEMINI.md: machine + gemini + system + behavior
  printf '%s\n\n%s\n\n---\n<!-- SHARED — synced from ~/h1ve/shared/GEMINI-shared.md + CLAUDE-system.md + CLAUDE-behavior.md -->\n\n%s\n\n%s\n\n%s\n' \
    "$BANNER" \
    "$MACHINE_CONTENT" \
    "$GEMINI_CONTENT" \
    "$SYSTEM_CONTENT" \
    "$BEHAVIOR_CONTENT" > "${MACHINE_DIR}GEMINI.md"

  echo "BUILT: ${MACHINE_NAME} (CLAUDE.md & GEMINI.md)"
  BUILT=$((BUILT + 1))
done

echo ""
echo "Done. $BUILT machine foundations built, $SKIPPED skipped."
