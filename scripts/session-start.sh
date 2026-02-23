#!/bin/bash
# Pulls the hive on first user prompt of each session
#
# Uses PPID-based lockfile so it fires exactly once per Claude Code process —
# including on --resume (which starts a new process with a new PID).
# Safe to wire to the UserPromptSubmit hook.

# Use TMPDIR if set, fall back to TEMP (Windows), fall back to /tmp
TMPDIR="${TMPDIR:-${TEMP:-/tmp}}"
LOCKFILE="$TMPDIR/hive-session-$PPID"

[ -f "$LOCKFILE" ] && exit 0

touch "$LOCKFILE" 2>/dev/null || exit 0

# Resolve repo location relative to this script (works on Linux, WSL, Git Bash)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" && git pull --quiet 2>/dev/null || true
