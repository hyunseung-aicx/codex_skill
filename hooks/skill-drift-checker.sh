#!/usr/bin/env bash
# Warn when harness files change without matching documentation/progress updates.

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

changed="$(git diff --name-only --cached 2>/dev/null || true)"
if [ -z "$changed" ]; then
    changed="$(git diff --name-only 2>/dev/null || true)"
fi

[ -z "$changed" ] && exit 0

harness_changed="false"
docs_changed="false"

if printf '%s\n' "$changed" | grep -qE '^(skills|rules|hooks|commands)/'; then
    harness_changed="true"
fi

if printf '%s\n' "$changed" | grep -qE '^(docs|progress|README\.md|settings)/'; then
    docs_changed="true"
fi

if [ "$harness_changed" = "true" ] && [ "$docs_changed" != "true" ]; then
    cat <<'EOF'
{"decision":"block","reason":"[SKILL-DRIFT] skills/rules/hooks/commands changed without docs/progress/settings update. Add a short rationale or update progress/BOARD.md."}
EOF
    exit 0
fi

exit 0
