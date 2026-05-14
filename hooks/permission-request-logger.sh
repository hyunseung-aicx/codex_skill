#!/bin/bash
# shellcheck shell=bash
# PermissionRequest: 권한 요청 시점 감사 로그
# 사용자가 prompt를 보고 승인/거부 결정하기 전 단계를 기록
# (PermissionDenied와 짝 — denied는 결과만, 여기는 모든 요청)
# Source: src/types/hooks.ts - PermissionRequest event (2026)
#
# 효과:
# - 어떤 도구/패턴이 자주 prompt를 띄우는지 통계로 → settings.json allow에 추가 후보 발굴
# - "왜 이렇게 자주 prompt가 뜨지?" 의문 해소

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .toolName // "unknown"' 2>/dev/null)
  PATTERN=$(echo "$INPUT" | jq -r '.pattern // .rule // empty' 2>/dev/null)
else
  read -r TOOL_NAME PATTERN < <(HOOK_INPUT="$INPUT" python -c '
import json, os
try:
    d = json.loads(os.environ["HOOK_INPUT"])
    print(d.get("tool_name", d.get("toolName", "unknown")), d.get("pattern", d.get("rule", "")))
except Exception: print("unknown", "")
' 2>/dev/null)
fi

LOG_DIR="${HOME}/.claude/traces"
mkdir -p "$LOG_DIR"
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"PermissionRequest\",\"tool\":\"${TOOL_NAME}\",\"pattern\":\"${PATTERN}\",\"session\":\"${CLAUDE_SESSION_ID:-unknown}\"}" >> "${LOG_DIR}/permission-requests.jsonl"

# 이 세션에서 같은 패턴이 3회+ prompt 발생 시 allow 추가 권유
SESSION_KEY="${CLAUDE_SESSION_ID:-$$}"
COUNTER_FILE="${TMPDIR:-/tmp}/claude-perm-requests-${SESSION_KEY}"
mkdir -p "$(dirname "$COUNTER_FILE")"

KEY="${TOOL_NAME}|${PATTERN}"
COUNT=$(grep -F "${KEY}=" "$COUNTER_FILE" 2>/dev/null | head -1 | cut -d= -f2 || echo 0)
COUNT=$((COUNT + 1))

if [ -f "$COUNTER_FILE" ]; then
  grep -vF "${KEY}=" "$COUNTER_FILE" > "${COUNTER_FILE}.tmp" 2>/dev/null || true
  mv "${COUNTER_FILE}.tmp" "$COUNTER_FILE" 2>/dev/null || true
fi
echo "${KEY}=${COUNT}" >> "$COUNTER_FILE"

if [ "$COUNT" -ge 3 ]; then
  echo "" >&2
  echo "💡 ${TOOL_NAME}(${PATTERN}) 권한 요청 ${COUNT}회 — 자주 쓴다면 settings.json allow에 추가 고려" >&2
  echo "" >&2
fi

exit 0
