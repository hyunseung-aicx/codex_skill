#!/usr/bin/env bash
# Health check for the Codex global Claude skillpack installation.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

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
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
AGENTS_DIR="${AGENTS_HOME:-$HOME/.agents}"
CODEX_SKILLS_DIR="$CODEX_DIR/skills"
AGENTS_SKILLS_DIR="$AGENTS_DIR/skills"
PACK_DIR="$CODEX_DIR/claude-skillpack"

failures=0
warnings=0

ok() { echo -e "  ${GREEN}+${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; warnings=$((warnings + 1)); }
fail() { echo -e "  ${RED}x${NC} $1"; failures=$((failures + 1)); }

count_source_skills() {
    find "$ROOT_DIR/skills" -mindepth 2 -maxdepth 2 -type f -name SKILL.md 2>/dev/null | wc -l | tr -d ' '
}

count_visible_skills() {
    local dir="$1"
    find -L "$dir" -maxdepth 2 -type f -name SKILL.md 2>/dev/null | wc -l | tr -d ' '
}

check_dir_count() {
    local label="$1"
    local dir="$2"
    local expected="$3"
    local actual

    actual="$(count_visible_skills "$dir")"
    if [ "$actual" = "$expected" ]; then
        ok "$label sees $actual/$expected skills"
    else
        fail "$label sees $actual/$expected skills at $dir"
    fi
}

check_link_target() {
    local path="$1"
    local expected_prefix="$2"
    local target

    if [ ! -L "$path" ]; then
        fail "$path is not a symlink"
        return
    fi
    target="$(readlink "$path")"
    case "$target" in
        "$expected_prefix"*) ok "$path -> $target" ;;
        *) fail "$path points to $target, expected prefix $expected_prefix" ;;
    esac
}

echo -e "${CYAN}Codex Claude Skillpack Doctor${NC}"
echo "Source: $ROOT_DIR"
echo "Codex:  $CODEX_DIR"
echo "Agents: $AGENTS_DIR"
echo ""

expected_skills="$(count_source_skills)"
if [ "$expected_skills" -lt 1 ]; then
    fail "No source skills found"
else
    ok "Source contains $expected_skills skills"
fi

check_dir_count "Codex CLI/GUI" "$CODEX_SKILLS_DIR" "$expected_skills"
check_dir_count "Open agent skill discovery" "$AGENTS_SKILLS_DIR" "$expected_skills"

echo ""
echo -e "${CYAN}Link targets${NC}"
check_link_target "$CODEX_SKILLS_DIR/codex-claude-skillpack" "$ROOT_DIR/skills/"
check_link_target "$AGENTS_SKILLS_DIR/codex-claude-skillpack" "$ROOT_DIR/skills/"
check_link_target "$PACK_DIR/commands" "$ROOT_DIR/"
check_link_target "$PACK_DIR/rules" "$ROOT_DIR/"
check_link_target "$PACK_DIR/agents" "$ROOT_DIR/"
check_link_target "$PACK_DIR/hooks" "$ROOT_DIR/"

echo ""
echo -e "${CYAN}Skill metadata${NC}"
bad_metadata=0
while IFS= read -r skill_file; do
    if ! sed -n '1,12p' "$skill_file" | grep -q '^name:'; then
        echo "  missing name: $skill_file"
        bad_metadata=$((bad_metadata + 1))
    fi
    if ! sed -n '1,12p' "$skill_file" | grep -q '^description:'; then
        echo "  missing description: $skill_file"
        bad_metadata=$((bad_metadata + 1))
    fi
done < <(find "$ROOT_DIR/skills" -mindepth 2 -maxdepth 2 -type f -name SKILL.md | sort)
if [ "$bad_metadata" -eq 0 ]; then
    ok "All SKILL.md files have name and description metadata"
else
    fail "$bad_metadata metadata issue(s) found"
fi

echo ""
echo -e "${CYAN}Claude resource coverage${NC}"
for resource in agents commands hooks progress rules CLAUDE.md GUIDE.md MCP_QUICK_SETUP.md README.md settings.local.json; do
    if [ -L "$PACK_DIR/$resource" ] || [ -e "$PACK_DIR/$resource" ]; then
        ok "$resource linked"
    else
        fail "$resource missing from $PACK_DIR"
    fi
done

echo ""
echo -e "${CYAN}Git freshness${NC}"
if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    head_rev="$(git -C "$ROOT_DIR" rev-parse HEAD)"
    if git -C "$ROOT_DIR" rev-parse origin/main >/dev/null 2>&1; then
        origin_rev="$(git -C "$ROOT_DIR" rev-parse origin/main)"
        if [ "$head_rev" = "$origin_rev" ]; then
            ok "HEAD matches origin/main ($head_rev)"
        else
            warn "HEAD differs from origin/main; run codex-skillpack-update"
        fi
    else
        warn "origin/main is unavailable locally; run codex-skillpack-update"
    fi

    dirty="$(git -C "$ROOT_DIR" status --short)"
    if [ -n "$dirty" ]; then
        warn "Repository has local changes; expected when Codex adapter files are uncommitted"
    else
        ok "Repository working tree is clean"
    fi
else
    warn "Source is not a git repository"
fi

echo ""
if [ "$failures" -eq 0 ]; then
    if [ "$warnings" -eq 0 ]; then
        echo -e "${GREEN}Score: 96/100 - production-ready Codex global skillpack setup.${NC}"
    else
        echo -e "${YELLOW}Score: 92/100 - healthy with $warnings warning(s).${NC}"
    fi
    exit 0
fi

echo -e "${RED}Score: 70/100 - $failures failure(s), $warnings warning(s). Re-run setup_codex.sh.${NC}"
exit 1
