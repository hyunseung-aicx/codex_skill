#!/usr/bin/env bash
# Inspect Codex skills for metadata, size, staleness, and maintenance signals.

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
SKILLS_DIR="$ROOT_DIR/skills"
REPORT="$ROOT_DIR/progress/SKILL_CURATOR.md"

now_iso() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

git_last_changed_days() {
    local file="$1"
    local ts
    ts="$(git -C "$ROOT_DIR" log -1 --format=%ct -- "$file" 2>/dev/null || true)"
    if [ -z "$ts" ]; then
        echo "unknown"
        return
    fi
    local now
    now="$(date +%s)"
    echo $(( (now - ts) / 86400 ))
}

line_count() {
    wc -l < "$1" | tr -d ' '
}

skill_name_from_meta() {
    sed -n '1,20p' "$1" | awk -F': *' '/^name:/ {print $2; exit}'
}

skill_description_present() {
    sed -n '1,20p' "$1" | grep -q '^description:'
}

mkdir -p "$ROOT_DIR/progress"

total=0
metadata_issues=0
large_skills=0
stale_skills=0
missing_examples=0

tmp_table="$(mktemp)"
trap 'rm -f "$tmp_table"' EXIT

while IFS= read -r skill_file; do
    total=$((total + 1))
    rel="${skill_file#$ROOT_DIR/}"
    name="$(basename "$(dirname "$skill_file")")"
    meta_name="$(skill_name_from_meta "$skill_file")"
    lines="$(line_count "$skill_file")"
    age_days="$(git_last_changed_days "$skill_file")"
    flags=""

    if [ -z "$meta_name" ] || ! skill_description_present "$skill_file"; then
        metadata_issues=$((metadata_issues + 1))
        flags="${flags} metadata"
    fi

    if [ "$lines" -gt 700 ]; then
        large_skills=$((large_skills + 1))
        flags="${flags} large"
    fi

    if [ "$age_days" != "unknown" ] && [ "$age_days" -gt 90 ]; then
        stale_skills=$((stale_skills + 1))
        flags="${flags} stale-${age_days}d"
    fi

    if [ ! -f "$(dirname "$skill_file")/EXAMPLES.md" ] && ! find "$(dirname "$skill_file")" -maxdepth 2 -type f \( -name '*test*' -o -name '*.example.*' -o -name 'examples.md' \) | grep -q .; then
        missing_examples=$((missing_examples + 1))
        flags="${flags} no-examples"
    fi

    [ -z "$flags" ] && flags="ok"
    printf '| `%s` | %s | %s | %s |\n' "$name" "$lines" "$age_days" "$flags" >> "$tmp_table"
done < <(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -type f -name SKILL.md | sort)

{
    echo "# Skill Curator Report"
    echo
    echo "Updated: $(now_iso)"
    echo
    echo "## Summary"
    echo
    echo "- Total skills: $total"
    echo "- Metadata issues: $metadata_issues"
    echo "- Large skills (>700 lines): $large_skills"
    echo "- Stale skills (>90 days since last git change): $stale_skills"
    echo "- Skills without local examples/tests: $missing_examples"
    echo
    echo "## Recommended Actions"
    echo
    if [ "$metadata_issues" -gt 0 ]; then
        echo "- Fix missing \`name\` or \`description\` metadata before adding more skills."
    fi
    if [ "$large_skills" -gt 0 ]; then
        echo "- Split large skills or move reference material into \`references/\`."
    fi
    if [ "$stale_skills" -gt 0 ]; then
        echo "- Review stale skills for framework/API drift."
    fi
    if [ "$missing_examples" -gt 0 ]; then
        echo "- Add examples/tests to high-use skills first; not every advisory skill needs code tests."
    fi
    if [ "$metadata_issues" -eq 0 ] && [ "$large_skills" -eq 0 ]; then
        echo "- Curator found no blocking skill-health issues."
    fi
    echo
    echo "## Skill Table"
    echo
    echo "| Skill | Lines | Last changed days | Flags |"
    echo "| --- | ---: | ---: | --- |"
    cat "$tmp_table"
    echo
    echo "## Policy"
    echo
    echo "- Treat this as a review aid, not an automatic deletion tool."
    echo "- Archive or split skills only after human review."
    echo "- Convert repeated curator findings into \`progress/BOARD.md\` items."
} > "$REPORT"

echo "Wrote $REPORT"
