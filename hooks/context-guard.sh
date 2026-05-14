#!/bin/bash
# shellcheck shell=bash
# PostToolUse (Read|Glob|Grep): Context oxidation guard
# 메인 컨텍스트 창에서 탐색이 누적되면 의사결정 품질이 떨어지므로
# Read/Glob/Grep 누적 호출이 임계 초과 시 subagent 위임 권유
#
# Reference: HumanLayer "Skill Issue: Harness Engineering for Coding Agents"
#   - "pushing exploration to a separate window structurally prevents contamination"
# Reference: rules/agents.md — Explore subagent 위임 가이드

INPUT=$(cat)

# jq가 있으면 사용, 없으면 python fallback (Windows 친화)
if command -v jq >/dev/null 2>&1; then
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
else
  TOOL_NAME=$(HOOK_INPUT="$INPUT" python -c '
import json, os, sys
try: print(json.loads(os.environ["HOOK_INPUT"]).get("tool_name", ""))
except Exception: pass
' 2>/dev/null)
fi

# 탐색 도구만 카운트
case "$TOOL_NAME" in
  Read|Glob|Grep) ;;
  *) exit 0 ;;
esac

# Session-isolated counter
SESSION_KEY="${CLAUDE_SESSION_ID:-$$}"
COUNTER_FILE="${TMPDIR:-/tmp}/claude-context-guard-${SESSION_KEY}"
mkdir -p "$(dirname "$COUNTER_FILE")"

COUNT=0
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# 임계 (각 단계는 1회만 경고하도록 정확 일치 비교)
case "$COUNT" in
  15)
    echo "" >&2
    echo "🧭 Context Guard — 탐색 도구 누적 15회" >&2
    echo "   메인 창 오염 방지 권장: 다음 큰 탐색은 Explore subagent에 위임 고려" >&2
    echo "   예: Agent({subagent_type:'Explore', prompt:'...탐색 질문...'})" >&2
    echo "" >&2
    ;;
  30)
    echo "" >&2
    echo "🚨 Context Guard — 탐색 누적 30회" >&2
    echo "   메인 창에 누적 노이즈가 의사결정 품질을 떨어뜨릴 수 있음" >&2
    echo "   /compact 또는 새 작업은 subagent로 분리 강력 권장" >&2
    echo "" >&2
    ;;
  50)
    echo "" >&2
    echo "🛑 Context Guard — 탐색 누적 50회 — /clear 후 재시작 권유" >&2
    echo "" >&2
    ;;
esac

exit 0
