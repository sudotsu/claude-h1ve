#!/bin/bash
# Pull latest, commit local changes, push
# Run at the end of every session

set -e

cd "$(dirname "$0")/.."

echo "Pulling latest..."
git pull --rebase

if [ -n "$(git status --porcelain)" ]; then
  echo "Syncing changes..."
  git add -A
  git commit -m "sync: $(hostname -s) $(date +%Y-%m-%d-%H%M)"
  git push
  echo "Done."
else
  echo "Already up to date."
fi
