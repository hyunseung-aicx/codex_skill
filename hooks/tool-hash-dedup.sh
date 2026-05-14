#!/usr/bin/env bash
# tool-hash-dedup.sh — Tool-input hash 중복 감지 (Harness v6 P1)
#
# WHY: Anhaia $47K/11일 사고가 정확히 agent A↔B ping-pong 패턴 — analyzer가 X를 만들면 verifier가 되돌리고 반복.
#      파일 편집 횟수만 보는 loop-detector는 이 패턴을 못 잡음 — tool-input 자체의 hash 중복이 본질 시그널.
#      출처: https://dev.to/gabrielanhaia/the-agent-that-spent-47k-on-itself-an-autonomous-loop-postmortem-3313
#
# 동작: PostToolUse 시 sha256(tool_name + tool_input) 계산 → 세션별 counter.
#       임계치(5회+) 초과 시 escalate. async 가능.
#
# 환경변수:
#   CLAUDE_DEDUP_THRESHOLD (기본 5)
#   CLAUDE_DEDUP_MODE     = warn | block (기본 warn)
#
# 입력: stdin JSON { session_id, tool_name, tool_input, ... }
# 출력: ~/.claude/traces/tool-dedup.jsonl, 임계 초과 시 stderr 경고

set -uo pipefail

readonly TRACES_DIR="${HOME}/.claude/traces"
readonly STATE_DIR="${HOME}/.claude/dedup-state"
readonly DEDUP_LOG="${TRACES_DIR}/tool-dedup.jsonl"
readonly THRESHOLD="${CLAUDE_DEDUP_THRESHOLD:-5}"
readonly MODE="${CLAUDE_DEDUP_MODE:-warn}"

mkdir -p "$TRACES_DIR" "$STATE_DIR"

if ! command -v jq >/dev/null 2>&1 || ! command -v shasum >/dev/null 2>&1; then
  exit 0
fi

INPUT="$(cat 2>/dev/null || echo '{}')"
SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // "unknown"')"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // ""')"
TOOL_INPUT="$(echo "$INPUT" | jq -c '.tool_input // {}')"

[ -z "$TOOL_NAME" ] && exit 0

# 추적 제외 도구 (탐색은 반복이 정상)
case "$TOOL_NAME" in
  Read|Grep|Glob|TaskList|TaskGet|TaskOutput|TaskCreate|TaskUpdate|TaskStop) exit 0 ;;
esac

# hash 계산
HASH=$(echo "${TOOL_NAME}:${TOOL_INPUT}" | shasum -a 256 | cut -d' ' -f1 | head -c 16)

# 세션별 counter 파일
COUNTER_FILE="${STATE_DIR}/${SESSION_ID}.tsv"
touch "$COUNTER_FILE"

# 기존 count 가져오기 + 증가
CURRENT_COUNT=$(awk -F'\t' -v h="$HASH" '$1==h {print $2}' "$COUNTER_FILE" | tail -1)
[ -z "$CURRENT_COUNT" ] && CURRENT_COUNT=0
NEW_COUNT=$((CURRENT_COUNT + 1))

# counter 갱신 (in-place update)
TMP_FILE="${COUNTER_FILE}.tmp"
awk -F'\t' -v h="$HASH" -v n="$NEW_COUNT" -v t="$TOOL_NAME" '
  BEGIN { found=0 }
  $1==h { print $1"\t"n"\t"t; found=1; next }
  { print }
  END { if (!found) print h"\t"n"\t"t }
' "$COUNTER_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$COUNTER_FILE"

# 임계 초과 시 처리
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [ "$NEW_COUNT" -ge "$THRESHOLD" ]; then
  REASON="Tool-input hash repeated ${NEW_COUNT}× (threshold ${THRESHOLD}): ${TOOL_NAME}/${HASH}. Likely agent ping-pong or loop."
  echo "{\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\",\"action\":\"ESCALATE\",\"tool\":\"$TOOL_NAME\",\"hash\":\"$HASH\",\"count\":$NEW_COUNT,\"reason\":\"$REASON\"}" >> "$DEDUP_LOG"

  if [ "$MODE" = "block" ]; then
    echo "{\"decision\":\"block\",\"reason\":\"$REASON. Set CLAUDE_DEDUP_MODE=warn to disable.\"}"
    exit 2
  fi

  echo "🔄 Tool ping-pong detected: $TOOL_NAME repeated $NEW_COUNT times. Consider rethinking approach." >&2
elif [ "$NEW_COUNT" -ge $((THRESHOLD - 2)) ]; then
  # 임계 -2 도달 시 사전 경고
  echo "{\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\",\"action\":\"WARN\",\"tool\":\"$TOOL_NAME\",\"hash\":\"$HASH\",\"count\":$NEW_COUNT}" >> "$DEDUP_LOG"
fi

exit 0
