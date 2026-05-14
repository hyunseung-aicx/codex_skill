#!/bin/bash
# shellcheck shell=bash
# FileChanged: External file change detector
# 외부 도구(IDE, 다른 터미널)가 파일을 수정했을 때 reload 알림
# Source: src/types/hooks.ts - FileChanged event (2026)
#
# 효과:
# - Claude Code가 캐시한 파일과 디스크의 실제 내용이 어긋나는 doom loop 방지
# - 외부 변경을 감지하면 다음 Read에서 stale 캐시 무효화 시그널

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.filePath // .file_path // empty' 2>/dev/null)
  CHANGE_TYPE=$(echo "$INPUT" | jq -r '.changeType // "modified"' 2>/dev/null)
else
  read -r FILE_PATH CHANGE_TYPE < <(HOOK_INPUT="$INPUT" python -c '
import json, os
try:
    d = json.loads(os.environ["HOOK_INPUT"])
    print(d.get("filePath", d.get("file_path", "")), d.get("changeType", "modified"))
except Exception: print("", "modified")
' 2>/dev/null)
fi

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Trace log
LOG_DIR="${HOME}/.claude/traces"
mkdir -p "$LOG_DIR"
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"FileChanged\",\"file\":\"${FILE_PATH}\",\"type\":\"${CHANGE_TYPE}\",\"session\":\"${CLAUDE_SESSION_ID:-unknown}\"}" >> "${LOG_DIR}/file-events.jsonl"

# 세션-내 파일 변경 카운터 (동일 파일이 5회+ 외부 변경되면 협업 충돌 의심)
SESSION_KEY="${CLAUDE_SESSION_ID:-$$}"
COUNTER_FILE="${TMPDIR:-/tmp}/claude-file-changes-${SESSION_KEY}"
mkdir -p "$(dirname "$COUNTER_FILE")"

# 파일 경로별 카운트 (간단 형식: file=count)
COUNT=$(grep -F "${FILE_PATH}=" "$COUNTER_FILE" 2>/dev/null | head -1 | cut -d= -f2 || echo 0)
COUNT=$((COUNT + 1))

# 기존 라인 제거 후 새 카운트 기록
if [ -f "$COUNTER_FILE" ]; then
  grep -vF "${FILE_PATH}=" "$COUNTER_FILE" > "${COUNTER_FILE}.tmp" 2>/dev/null || true
  mv "${COUNTER_FILE}.tmp" "$COUNTER_FILE" 2>/dev/null || true
fi
echo "${FILE_PATH}=${COUNT}" >> "$COUNTER_FILE"

# 5회+ 외부 변경 시 사용자에게 경고
if [ "$COUNT" -ge 5 ]; then
  echo "" >&2
  echo "⚠️  FileChanged 누적 ${COUNT}회: $(basename "$FILE_PATH")" >&2
  echo "   외부에서 같은 파일을 반복 수정 중 — 변경 의도 충돌 가능. 잠시 동기화 필요." >&2
  echo "" >&2
fi

exit 0
