#!/bin/bash
# Syncs the hive: stash local changes, pull latest, restore, propagate, commit, push
# Run at the end of every session (or wire to Claude Code's Stop hook)

set -e

cd "$(dirname "$0")/.."

# Stash any uncommitted changes so pull --rebase doesn't choke
STASHED=false
if [ -n "$(git status --porcelain)" ]; then
  echo "Stashing local changes..."
  git stash push -u -m "sync-autostash"
  STASHED=true
fi

echo "Pulling latest..."
git pull --rebase

if [ "$STASHED" = true ]; then
  echo "Restoring local changes..."
  if ! git stash pop; then
    echo ""
    echo "========================================="
    echo "CRITICAL: MERGE CONFLICT IN HIVE FILES"
    echo "========================================="
    echo "git stash pop failed — conflict markers are in your working tree."
    echo "Resolve manually before continuing:"
    echo "  cd $(pwd)"
    echo "  git diff  (to see conflicts)"
    echo "  # fix the files, then:"
    echo "  git add -A && git stash drop && bash scripts/sync.sh"
    echo "========================================="
    exit 1
  fi
fi

# Rebuild all machine CLAUDE.md files from source
echo "Propagating shared instructions..."
bash "$(dirname "$0")/propagate.sh"

if [ -n "$(git status --porcelain)" ]; then
  echo "Changes detected, syncing..."
  git add -A
  git commit -m "sync: $(hostname -s) $(date +%Y-%m-%d-%H%M)"
  git push
  echo "Synced."
else
  echo "Already up to date."
fi
