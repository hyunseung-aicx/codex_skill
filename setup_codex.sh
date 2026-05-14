#!/usr/bin/env bash
# Codex Skills - Global Setup Script (macOS/Linux)
# Installs this Claude Code skillpack for Codex CLI and Codex GUI.
# It links skills into both the Codex desktop home and the open agent skills
# home so terminal, GUI, and standards-based skill discovery all see the same
# source of truth.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
CODEX_SKILLS_DIR="$CODEX_DIR/skills"
AGENTS_DIR="${AGENTS_HOME:-$HOME/.agents}"
AGENTS_SKILLS_DIR="$AGENTS_DIR/skills"
PACK_DIR="$CODEX_DIR/claude-skillpack"
BIN_DIR="$CODEX_DIR/bin"

success_count=0
fail_count=0

echo -e "${CYAN}==================================================${NC}"
echo -e "${CYAN}  Claude Skillpack -> Codex Global Setup${NC}"
echo -e "${CYAN}==================================================${NC}"
echo ""
echo -e "${GREEN}Repository: $SCRIPT_DIR${NC}"
echo -e "${GREEN}Codex home: $CODEX_DIR${NC}"
echo -e "${GREEN}Agent skills home: $AGENTS_SKILLS_DIR${NC}"
echo ""

mkdir -p "$CODEX_SKILLS_DIR" "$AGENTS_SKILLS_DIR" "$PACK_DIR" "$BIN_DIR"

create_symlink() {
    local target="$1"
    local link="$2"
    local name
    name="$(basename "$link")"

    if [ -L "$link" ]; then
        rm -f "$link"
    elif [ -e "$link" ]; then
        echo -e "  ${YELLOW}!${NC} $name - existing non-symlink, skipped"
        fail_count=$((fail_count + 1))
        return 1
    fi

    if ln -s "$target" "$link"; then
        echo -e "  ${GREEN}+${NC} $name"
        success_count=$((success_count + 1))
        return 0
    fi

    echo -e "  ${RED}x${NC} $name - failed"
    fail_count=$((fail_count + 1))
    return 1
}

install_skills_to() {
    local destination="$1"
    local label="$2"

    echo -e "${CYAN}Installing skills for $label...${NC}"
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
            skill_name="$(basename "$skill_dir")"
            create_symlink "$skill_dir" "$destination/$skill_name" >/dev/null || true
            if [ -L "$destination/$skill_name" ]; then
                echo -e "  ${GREEN}+${NC} $skill_name"
            fi
        fi
    done
    echo ""
}

install_skills_to "$CODEX_SKILLS_DIR" "Codex CLI/GUI"
install_skills_to "$AGENTS_SKILLS_DIR" "open agent skill discovery"

echo -e "${CYAN}Installing terminal maintenance commands...${NC}"
for command_name in codex-skillpack-doctor codex-skillpack-update codex-goal; do
    command_path="$SCRIPT_DIR/scripts/$command_name.sh"
    if [ -f "$command_path" ]; then
        chmod +x "$command_path" 2>/dev/null || true
        create_symlink "$command_path" "$BIN_DIR/$command_name" || true
        if [ -w /usr/local/bin ]; then
            create_symlink "$command_path" "/usr/local/bin/$command_name" || true
        else
            echo -e "  ${YELLOW}-${NC} /usr/local/bin not writable; use $BIN_DIR/$command_name or add $BIN_DIR to PATH"
        fi
    fi
done

echo ""
echo -e "${CYAN}Installing Claude resources for Codex reference...${NC}"
for resource in agents commands hooks progress rules; do
    if [ -e "$SCRIPT_DIR/$resource" ]; then
        create_symlink "$SCRIPT_DIR/$resource" "$PACK_DIR/$resource" || true
    fi
done

for file in CLAUDE.md GUIDE.md MCP_QUICK_SETUP.md README.md settings.local.json; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        create_symlink "$SCRIPT_DIR/$file" "$PACK_DIR/$file" || true
    fi
done

echo ""
echo -e "${CYAN}Verifying Codex skill links...${NC}"
installed_skill_count="$(find -L "$CODEX_SKILLS_DIR" -maxdepth 2 -type f -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
agent_skill_count="$(find -L "$AGENTS_SKILLS_DIR" -maxdepth 2 -type f -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
pack_resource_count="$(find "$PACK_DIR" -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')"
echo -e "  ${GREEN}+${NC} $installed_skill_count SKILL.md files visible under $CODEX_SKILLS_DIR"
echo -e "  ${GREEN}+${NC} $agent_skill_count SKILL.md files visible under $AGENTS_SKILLS_DIR"
echo -e "  ${GREEN}+${NC} $pack_resource_count skillpack resources linked under $PACK_DIR"

echo ""
echo -e "${CYAN}Python dependency notes:${NC}"
for skill in product-planner llm-app-planner; do
    req_file="$SCRIPT_DIR/skills/$skill/requirements.txt"
    if [ -f "$req_file" ]; then
        echo -e "  ${YELLOW}-${NC} $skill has optional dependencies: $req_file"
    fi
done

echo ""
echo -e "${CYAN}==================================================${NC}"
if [ "$fail_count" -eq 0 ]; then
    echo -e "${GREEN}Codex setup complete.${NC}"
else
    echo -e "${YELLOW}Codex setup complete with $fail_count skipped item(s).${NC}"
fi
echo -e "${CYAN}==================================================${NC}"
echo ""
echo -e "${BLUE}Restart Codex CLI/GUI or start a new Codex session so newly linked skill metadata is reloaded.${NC}"
echo -e "${BLUE}Resources are available at: $PACK_DIR${NC}"
echo -e "${BLUE}Health check: $BIN_DIR/codex-skillpack-doctor${NC}"
