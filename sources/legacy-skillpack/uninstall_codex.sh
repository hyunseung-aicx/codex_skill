#!/usr/bin/env bash
# Removes only symlinks created by setup_codex.sh. Real files/directories are left untouched.

set -euo pipefail

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
CODEX_SKILLS_DIR="$CODEX_DIR/skills"
AGENTS_DIR="${AGENTS_HOME:-$HOME/.agents}"
AGENTS_SKILLS_DIR="$AGENTS_DIR/skills"
PACK_DIR="$CODEX_DIR/claude-skillpack"
BIN_DIR="$CODEX_DIR/bin"

echo -e "${CYAN}Removing Codex symlinks for this skillpack...${NC}"

remove_skill_links_from() {
    local dir="$1"
    local label="$2"

    echo -e "${CYAN}$label${NC}"
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        if [ ! -d "$skill_dir" ]; then
            continue
        fi
        skill_name="$(basename "$skill_dir")"
        link="$dir/$skill_name"
        if [ -L "$link" ] && [ "$(readlink "$link")" = "$skill_dir" ]; then
            rm -f "$link"
            echo -e "  ${GREEN}-${NC} $skill_name"
        elif [ -e "$link" ]; then
            echo -e "  ${YELLOW}!${NC} $skill_name - not this setup's symlink, skipped"
        fi
    done
}

remove_skill_links_from "$CODEX_SKILLS_DIR" "Codex skills"
remove_skill_links_from "$AGENTS_SKILLS_DIR" "Open agent skills"

for command_name in codex-skillpack-doctor codex-skillpack-update codex-goal; do
    command_path="$SCRIPT_DIR/scripts/$command_name.sh"
    for link in "$BIN_DIR/$command_name" "/usr/local/bin/$command_name"; do
        if [ -L "$link" ] && [ "$(readlink "$link")" = "$command_path" ]; then
            rm -f "$link"
            echo -e "  ${GREEN}-${NC} $link"
        fi
    done
done

if [ -d "$PACK_DIR" ]; then
    for item in "$PACK_DIR"/*; do
        [ -e "$item" ] || continue
        if [ -L "$item" ]; then
            target="$(readlink "$item")"
            case "$target" in
                "$SCRIPT_DIR"/*)
                    rm -f "$item"
                    echo -e "  ${GREEN}-${NC} $(basename "$item")"
                    ;;
            esac
        fi
    done
    rmdir "$PACK_DIR" 2>/dev/null || true
fi

echo -e "${GREEN}Done.${NC}"
