#!/bin/bash
# shellcheck shell=bash
# CwdChanged: Working directory transition handler
# cd로 작업 디렉토리가 바뀔 때 새 디렉토리의 git/언어 컨텍스트 자동 갱신
# Source: src/types/hooks.ts - CwdChanged event (2026)
#
# 효과:
# - 멀티 프로젝트 작업 시 컨텍스트 혼선 방지
# - 새 프로젝트의 .git/HEAD, package.json, pyproject.toml 등 즉시 인식

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
  OLD_CWD=$(echo "$INPUT" | jq -r '.oldCwd // .old_cwd // empty' 2>/dev/null)
  NEW_CWD=$(echo "$INPUT" | jq -r '.newCwd // .new_cwd // empty' 2>/dev/null)
else
  read -r OLD_CWD NEW_CWD < <(HOOK_INPUT="$INPUT" python -c '
import json, os
try:
    d = json.loads(os.environ["HOOK_INPUT"])
    print(d.get("oldCwd", d.get("old_cwd", "")), d.get("newCwd", d.get("new_cwd", "")))
except Exception: print("", "")
' 2>/dev/null)
fi

if [ -z "$NEW_CWD" ]; then
  exit 0
fi

# Trace log
LOG_DIR="${HOME}/.claude/traces"
mkdir -p "$LOG_DIR"
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"CwdChanged\",\"oldCwd\":\"${OLD_CWD}\",\"newCwd\":\"${NEW_CWD}\",\"session\":\"${CLAUDE_SESSION_ID:-unknown}\"}" >> "${LOG_DIR}/cwd-events.jsonl"

# 새 디렉토리 컨텍스트 sniff (git 브랜치 + 프로젝트 타입)
if [ ! -d "$NEW_CWD" ]; then
  exit 0
fi

CONTEXT=""

# Git 브랜치
BRANCH=$(cd "$NEW_CWD" 2>/dev/null && git branch --show-current 2>/dev/null)
if [ -n "$BRANCH" ]; then
  CONTEXT="${CONTEXT}git=${BRANCH} "
fi

# 프로젝트 타입 감지
[ -f "$NEW_CWD/package.json" ] && CONTEXT="${CONTEXT}node "
[ -f "$NEW_CWD/pyproject.toml" ] || [ -f "$NEW_CWD/requirements.txt" ] && CONTEXT="${CONTEXT}python "
[ -f "$NEW_CWD/go.mod" ] && CONTEXT="${CONTEXT}go "
[ -f "$NEW_CWD/Cargo.toml" ] && CONTEXT="${CONTEXT}rust "
[ -f "$NEW_CWD/Dockerfile" ] && CONTEXT="${CONTEXT}docker "

# 프로젝트가 바뀐 경우 (path basename 변경) 사용자에게 알림
if [ -n "$OLD_CWD" ] && [ "$(basename "$OLD_CWD")" != "$(basename "$NEW_CWD")" ]; then
  echo "📁 cwd: $(basename "$NEW_CWD")  [${CONTEXT}]" >&2
fi

exit 0
