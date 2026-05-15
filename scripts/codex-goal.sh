#!/usr/bin/env bash
# Create a durable Codex goal packet for long-running GUI/terminal work.

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  codex-goal "goal text" [--hours N] [--branch codex/goal-name] [--base main] [--verify "cmd"] [--worktree]

Creates:
  .codex-goals/<goal-id>/GOAL.md
  .codex-goals/<goal-id>/PROMPT.md
  .codex-goals/<goal-id>/STATUS.md

Use the PROMPT.md content in Codex GUI /goal, or run terminal Codex from the generated worktree/branch.

Note:
  Native Codex /goal requires features.goals = true in ~/.codex/config.toml.
USAGE
}

slugify() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9가-힣._-]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//' \
        | cut -c 1-48
}

GOAL_TEXT=""
HOURS="1"
BASE_BRANCH="main"
BRANCH_NAME=""
VERIFY_CMD=""
USE_WORKTREE="false"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --hours)
            HOURS="${2:?--hours requires a value}"
            shift 2
            ;;
        --branch)
            BRANCH_NAME="${2:?--branch requires a value}"
            shift 2
            ;;
        --base)
            BASE_BRANCH="${2:?--base requires a value}"
            shift 2
            ;;
        --verify)
            VERIFY_CMD="${2:?--verify requires a value}"
            shift 2
            ;;
        --worktree)
            USE_WORKTREE="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [ -z "$GOAL_TEXT" ]; then
                GOAL_TEXT="$1"
            else
                GOAL_TEXT="$GOAL_TEXT $1"
            fi
            shift
            ;;
    esac
done

if [ -z "$GOAL_TEXT" ]; then
    usage
    exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "codex-goal must be run inside a Git repository." >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

NOW="$(date '+%Y%m%d-%H%M%S')"
GOAL_SLUG="$(slugify "$GOAL_TEXT")"
if [ -z "$GOAL_SLUG" ]; then
    GOAL_SLUG="goal"
fi
GOAL_ID="$NOW-$GOAL_SLUG"
GOAL_DIR="$REPO_ROOT/.codex-goals/$GOAL_ID"

if [ -z "$BRANCH_NAME" ]; then
    BRANCH_NAME="codex/goal-$GOAL_SLUG"
fi

WORKTREE_DIR="$REPO_ROOT/.codex-goals/worktrees/${BRANCH_NAME//\//-}"

mkdir -p "$GOAL_DIR"

cat > "$GOAL_DIR/GOAL.md" <<EOF
# Codex Goal: $GOAL_TEXT

- Goal ID: $GOAL_ID
- Branch: $BRANCH_NAME
- Base: $BASE_BRANCH
- Timebox: ${HOURS}h
- Worktree mode: $USE_WORKTREE
- Verify command: ${VERIFY_CMD:-auto-detect}
- Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')

## Contract

Work in small checkpoints. Prefer reviewable diffs over broad rewrites. Keep commits or status notes scoped to this goal. Stop and ask for input if secrets, destructive data changes, schema migrations, paid external services, or ambiguous product decisions are required.
EOF

cat > "$GOAL_DIR/PROMPT.md" <<EOF
/goal

Use the native Codex /goal workflow plus the local goal-runner harness.

Objective:
$GOAL_TEXT

Branch:
$BRANCH_NAME

Timebox:
${HOURS} hour(s). If the environment supports background work, use a worktree/automation-friendly flow. Otherwise work in checkpoints and leave STATUS.md current.

Verification:
${VERIFY_CMD:-Infer the smallest reliable test/build/lint commands from the repository.}

Operating loop:
1. Inspect the repo and write a short plan.
2. Create or continue the branch/worktree for this goal.
3. Implement in small slices.
4. Run targeted verification after each slice.
5. Update $GOAL_DIR/STATUS.md with progress, commands run, failures, and next step.
6. If the task runs long, keep going until the timebox, a stop condition, or verification blocker.
7. Before stopping, summarize changed files, verification status, residual risks, and exact next command/prompt to continue.

Stop conditions:
- destructive command
- production data or credentials
- paid service operation
- ambiguous product decision
- migration touching non-dev data
- diff that exceeds the goal contract

Use these local files:
- Goal contract: $GOAL_DIR/GOAL.md
- Status log: $GOAL_DIR/STATUS.md
- Agent board: $REPO_ROOT/progress/BOARD.md

After completion:
- Run scripts/codex-skill-curator.sh if skills/rules/hooks/commands changed.
- Run scripts/codex-memory-audit.sh if durable memory/progress files changed.
EOF

cat > "$GOAL_DIR/STATUS.md" <<EOF
# Status

- State: initialized
- Last update: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
- Current branch target: $BRANCH_NAME

## Progress

- Goal packet created.

## Verification

- Not run yet.

## Next Step

- Open Codex GUI or terminal in this repo and paste PROMPT.md, or start work in the generated worktree.
EOF

if [ "$USE_WORKTREE" = "true" ]; then
    mkdir -p "$(dirname "$WORKTREE_DIR")"
    if [ -e "$WORKTREE_DIR" ]; then
        echo "Worktree already exists: $WORKTREE_DIR"
    else
        git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR" "$BASE_BRANCH"
    fi
else
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        echo "Branch already exists: $BRANCH_NAME"
    else
        git branch "$BRANCH_NAME" "$BASE_BRANCH"
    fi
fi

echo "Goal packet created:"
echo "  $GOAL_DIR"
echo ""
echo "Branch:"
echo "  $BRANCH_NAME"
if [ "$USE_WORKTREE" = "true" ]; then
    echo "Worktree:"
    echo "  $WORKTREE_DIR"
fi
echo ""
echo "Next:"
echo "  Paste $GOAL_DIR/PROMPT.md into Codex GUI, or run terminal Codex from the repo/worktree."
