#!/bin/bash
# Quick sync helper — stash local changes, pull latest, restore, commit, push
set -e

cd "$(dirname "$0")/.."
SCRATCH="$(pwd)/scratch"
STATUS_FILE="$SCRATCH/last-sync-status"
mkdir -p "$SCRATCH"

# On any unexpected failure: write status file and print recovery instructions.
# Note: git stash pop failure is handled explicitly below and does not trigger this trap.
STASHED=false
trap '
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  echo "FAILED $TIMESTAMP" > "$STATUS_FILE"
  echo "Command failed — see sync output above." >> "$STATUS_FILE"
  echo ""
  echo "========================================="
  echo "SYNC FAILED"
  echo "========================================="
  if [ "${STASHED}" = true ]; then
    echo "Your changes were stashed before the failure. Recover with:"
    echo "  cd $(pwd)"
    echo "  git stash list"
    echo "  git stash pop"
    echo ""
  fi
  echo "Fix the issue above, then re-run: bash scripts/sync.sh"
  echo "========================================="
' ERR

check_orphaned_gitlinks() {
  local entry mode path key configured_path section url
  local -a orphaned=()

  while IFS= read -r -d '' entry; do
    mode=${entry%% *}
    [ "$mode" = "160000" ] || continue
    path=${entry#*$'\t'}
    section=""

    if [ -f .gitmodules ]; then
      while read -r key configured_path; do
        if [ "$configured_path" = "$path" ]; then
          section=${key%.path}
          url=$(git config -f .gitmodules --get "${section}.url" 2>/dev/null || true)
          [ -n "$url" ] && break
          section=""
        fi
      done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null || true)
    fi

    [ -n "$section" ] || orphaned+=("$path")
  done < <(git ls-files --stage -z)

  if [ ${#orphaned[@]} -eq 0 ]; then
    return 0
  fi

  echo ""
  echo "ERROR: orphaned gitlink(s) detected — refusing to commit:" >&2
  printf '  - %s\n' "${orphaned[@]}" >&2
  echo "" >&2
  echo "Each mode-160000 entry must have a matching path and URL in .gitmodules." >&2
  echo "Preserve any nested checkout and uncommitted work before repairing it." >&2
  echo "For normal H1VE project context, remove the gitlink from the index:" >&2
  echo "  git rm --cached -- <path>" >&2
  echo "Then replace it with normal files. If it is an intentional submodule," >&2
  echo "add or repair its .gitmodules path and URL before re-running sync." >&2
  return 1
}

# Stash any uncommitted changes so pull --rebase doesn't choke
if [ -n "$(git status --porcelain)" ]; then
  echo "Stashing local changes..."
  git stash push -u -m "sync-autostash"
  STASHED=true
fi

echo "Pulling latest..."
if ! git pull --rebase 2>/dev/null; then
  echo "Pull failed (offline or remote unavailable) — skipping sync"
  exit 0
fi

if [ "$STASHED" = true ]; then
  echo "Restoring local changes..."
  if ! git stash pop; then
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "FAILED $TIMESTAMP" > "$STATUS_FILE"
    echo "Merge conflict during stash pop — resolve manually." >> "$STATUS_FILE"
    echo ""
    echo "========================================="
    echo "CRITICAL: MERGE CONFLICT IN H1VE FILES"
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

# Propagate shared instructions to all machine CLAUDE.md files
echo "Propagating shared instructions..."
if ! bash "$(dirname "$0")/propagate.sh"; then
  echo "ERROR: propagate.sh failed — aborting sync to prevent committing broken CLAUDE.md files"
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Changes detected, syncing..."
  git add -A
  check_orphaned_gitlinks
  git commit -m "sync: $(hostname) $(date +%Y-%m-%d-%H%M)"
  if git push; then
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "OK $TIMESTAMP" > "$STATUS_FILE"
    echo "Synced."
  else
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "FAILED $TIMESTAMP" > "$STATUS_FILE"
    echo "Push failed — committed locally, will retry on next sync." >> "$STATUS_FILE"
    echo "Push failed (offline or remote unavailable) — changes committed locally, will push next sync"
  fi
else
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  echo "OK $TIMESTAMP" > "$STATUS_FILE"
  echo "Already up to date."
fi
