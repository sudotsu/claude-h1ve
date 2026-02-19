#!/bin/bash
# claude-h1ve installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/claude-h1ve/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/claude-h1ve/main/install.sh | bash -s -- my-machine-name

set -e

MACHINE_NAME="${1:-$(hostname -s)}"

echo ""
echo "  claude-h1ve"
echo "  ───────────"
echo ""

# Check dependencies
MISSING=()
for cmd in git gh; do
  command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "Missing: ${MISSING[*]}"
  echo ""
  [[ " ${MISSING[*]} " == *" gh "* ]] && echo "  Install gh:  https://cli.github.com/"
  [[ " ${MISSING[*]} " == *" git "* ]] && echo "  Install git: https://git-scm.com/"
  echo ""
  exit 1
fi

# Check gh auth
GH_USER=$(gh api user --jq '.login' 2>/dev/null) || {
  echo "Not logged into GitHub CLI. Run: gh auth login"
  exit 1
}

INSTALL_DIR="$HOME/hive"

# Clone or update
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "Hive found at $INSTALL_DIR — pulling latest..."
  cd "$INSTALL_DIR" && git pull --rebase
  echo ""
  echo "Already set up. To add this machine to the hive:"
  echo "  $INSTALL_DIR/scripts/new-machine.sh $MACHINE_NAME"
  exit 0
fi

if gh repo view "$GH_USER/claude-h1ve" &>/dev/null 2>&1; then
  echo "Cloning $GH_USER/claude-h1ve → $INSTALL_DIR"
  gh repo clone "$GH_USER/claude-h1ve" "$INSTALL_DIR"
else
  echo "No claude-h1ve repo found under your account ($GH_USER)."
  echo ""
  echo "First, create your own copy of the template:"
  echo "  1. Go to https://github.com/sudotsu/claude-h1ve"
  echo "  2. Click 'Use this template' → 'Create a new repository'"
  echo "  3. Name it 'claude-h1ve'"
  echo "  4. Re-run this installer"
  echo ""
  exit 0
fi

echo ""
bash "$INSTALL_DIR/scripts/new-machine.sh" "$MACHINE_NAME"
