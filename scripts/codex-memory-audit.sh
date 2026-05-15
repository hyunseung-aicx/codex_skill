#!/usr/bin/env bash
# Audit durable memory/progress files for temporal metadata and secret hygiene.

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
REPORT="$ROOT_DIR/progress/MEMORY_AUDIT.md"

now_iso() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

mkdir -p "$ROOT_DIR/progress"

secret_pattern='(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|github_pat_|xox[baprs]-|AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|DATABASE_URL=.*://)'

tmp_files="$(mktemp)"
tmp_secret_hits="$(mktemp)"
trap 'rm -f "$tmp_files" "$tmp_secret_hits"' EXIT

find "$ROOT_DIR/progress" "$ROOT_DIR/memory-schema" "$ROOT_DIR/docs" -type f \( -name '*.md' -o -name '*.json' -o -name '*.toml' \) | sort > "$tmp_files"
if [ -d "$ROOT_DIR/.codex-goals" ]; then
    find "$ROOT_DIR/.codex-goals" -type f -name '*.md' | sort >> "$tmp_files"
fi

total_files="$(wc -l < "$tmp_files" | tr -d ' ')"
temporal_files="$(xargs grep -lE 'valid_from:|valid_until:|supersedes:|confidence:' < "$tmp_files" 2>/dev/null | wc -l | tr -d ' ' || true)"
status_files="$(grep -E 'STATUS\.md$|BOARD\.md$|SKILL_CURATOR\.md$' "$tmp_files" | wc -l | tr -d ' ')"

while IFS= read -r file; do
    if grep -nE "$secret_pattern" "$file" >/dev/null 2>&1; then
        grep -nE "$secret_pattern" "$file" | sed "s#^#$file:#" >> "$tmp_secret_hits"
    fi
done < "$tmp_files"

secret_hits="$(wc -l < "$tmp_secret_hits" | tr -d ' ')"

{
    echo "# Memory Audit Report"
    echo
    echo "Updated: $(now_iso)"
    echo
    echo "## Summary"
    echo
    echo "- Files inspected: $total_files"
    echo "- Files with temporal metadata: $temporal_files"
    echo "- Durable status/board files: $status_files"
    echo "- Potential secret hits: $secret_hits"
    echo
    echo "## Findings"
    echo
    if [ "$secret_hits" -gt 0 ]; then
        echo "### Potential Secrets"
        echo
        echo "Review these immediately. Do not store secrets in memory or progress files."
        echo
        sed 's/^/- `/' "$tmp_secret_hits" | sed 's/$/`/'
        echo
    else
        echo "- No obvious secret patterns found in memory/progress/docs files."
    fi
    if [ "$temporal_files" -eq 0 ]; then
        echo "- No temporal metadata found. Durable memories should use \`valid_from\`, \`valid_until\`, \`supersedes\`, and \`confidence\` when facts may age."
    else
        echo "- Temporal memory metadata is present in at least $temporal_files file(s)."
    fi
    echo
    echo "## Recommended Actions"
    echo
    echo "- Keep personal/project facts source-linked and time-bounded."
    echo "- Move stale board items out of Active after 14 days."
    echo "- Use Memory MCP only for explicit durable facts, never secrets."
    echo "- After long \`/goal\` sessions, summarize durable decisions here or in \`progress/BOARD.md\`."
} > "$REPORT"

echo "Wrote $REPORT"
