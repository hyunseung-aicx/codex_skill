#!/usr/bin/env bash
# Fetches the latest main branch, reinstalls global symlinks, and runs doctor.

set -euo pipefail

SOURCE_PATH="${BASH_SOURCE[0]}"
while [ -L "$SOURCE_PATH" ]; do
    SOURCE_DIR="$(cd "$(dirname "$SOURCE_PATH")" && pwd)"
    LINK_TARGET="$(readlink "$SOURCE_PATH")"
    case "$LINK_TARGET" in
        /*) SOURCE_PATH="$LINK_TARGET" ;;
        *) SOURCE_PATH="$SOURCE_DIR/$LINK_TARGET" ;;
    esac
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Updating Codex Claude skillpack at $ROOT_DIR"

git -C "$ROOT_DIR" fetch --all --prune

current_branch="$(git -C "$ROOT_DIR" branch --show-current)"
if [ "$current_branch" = "main" ]; then
    git -C "$ROOT_DIR" merge --ff-only origin/main
else
    echo "Current branch is $current_branch; skipping merge. Checkout main to fast-forward from origin/main."
fi

"$ROOT_DIR/setup_codex.sh"
"$ROOT_DIR/scripts/codex-skillpack-doctor.sh"
