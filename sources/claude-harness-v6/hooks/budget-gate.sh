#!/usr/bin/env bash
# budget-gate.sh — USD 누적 예산 hard cap (Harness v6 P0)
#
# WHY: $47K/11일 자율 에이전트 사고 (Anhaia, 2026.03), $4,200/63h burn (Sattyam Jain, 2026.02).
#      토큰 80% 가드만으로는 1턴에 폭주하는 경우 못 잡음 — 달러 단위 enforcement 필요.
#      Portal26 Agentic Token Controls 패턴 (2026.04 발표).
#
# 동작: transcript에서 모델별 토큰 사용량 → 2026.05 단가로 USD 환산 → 임계치 초과 시 block.
#
# 임계치 (환경변수로 오버라이드 가능):
#   CLAUDE_BUDGET_SESSION_USD (기본 $5)
#   CLAUDE_BUDGET_DAILY_USD   (기본 $20)
#   CLAUDE_BUDGET_MODE = block | warn  (기본 block)
#
# 입력: stdin JSON { session_id, transcript_path, ... }
# 출력: ~/.claude/traces/budget.jsonl, 임계 초과 시 decision: block
# 종료 코드: 2 = block, 0 = pass

set -uo pipefail

readonly TRACES_DIR="${HOME}/.claude/traces"
readonly BUDGET_DIR="${HOME}/.claude/budget-state"
readonly BUDGET_LOG="${TRACES_DIR}/budget.jsonl"

mkdir -p "$TRACES_DIR" "$BUDGET_DIR"

SESSION_LIMIT="${CLAUDE_BUDGET_SESSION_USD:-5}"
DAILY_LIMIT="${CLAUDE_BUDGET_DAILY_USD:-20}"
MODE="${CLAUDE_BUDGET_MODE:-block}"

# jq 없으면 advisory pass
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT="$(cat 2>/dev/null || echo '{}')"
SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)"
TRANSCRIPT_PATH="$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)"

[ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ] && exit 0

# 2026.05 기준 단가 ($/MTok)
# Opus 4.7: input $15, output $75, cache_read $1.50, cache_creation $18.75
# Sonnet 4.6: input $3, output $15, cache_read $0.30, cache_creation $3.75
# Haiku 4.5: input $1, output $5, cache_read $0.10, cache_creation $1.25
calc_cost() {
  local model="$1" input="$2" output="$3" cache_read="$4" cache_creation="$5"
  local rate_in rate_out rate_cr rate_cc

  case "$model" in
    *opus*)   rate_in=15.0;  rate_out=75.0; rate_cr=1.50; rate_cc=18.75 ;;
    *sonnet*) rate_in=3.0;   rate_out=15.0; rate_cr=0.30; rate_cc=3.75 ;;
    *haiku*)  rate_in=1.0;   rate_out=5.0;  rate_cr=0.10; rate_cc=1.25 ;;
    *)        rate_in=3.0;   rate_out=15.0; rate_cr=0.30; rate_cc=3.75 ;;  # fallback Sonnet
  esac

  awk -v i="$input" -v o="$output" -v cr="$cache_read" -v cc="$cache_creation" \
      -v ri="$rate_in" -v ro="$rate_out" -v rcr="$rate_cr" -v rcc="$rate_cc" \
      'BEGIN { printf "%.6f", (i*ri + o*ro + cr*rcr + cc*rcc) / 1000000 }'
}

# transcript 모델별 토큰 집계
USAGE_JSON="$(jq -s '
  map(select(.message.usage != null) | {
    model: (.message.model // "unknown"),
    input: (.message.usage.input_tokens // 0),
    output: (.message.usage.output_tokens // 0),
    cache_read: (.message.usage.cache_read_input_tokens // 0),
    cache_creation: (.message.usage.cache_creation_input_tokens // 0)
  }) | group_by(.model) | map({
    model: .[0].model,
    input: (map(.input) | add // 0),
    output: (map(.output) | add // 0),
    cache_read: (map(.cache_read) | add // 0),
    cache_creation: (map(.cache_creation) | add // 0)
  })
' "$TRANSCRIPT_PATH" 2>/dev/null || echo '[]')"

SESSION_COST=0
while IFS= read -r row; do
  [ -z "$row" ] && continue
  MODEL=$(echo "$row" | jq -r '.model')
  IN=$(echo "$row" | jq -r '.input')
  OUT=$(echo "$row" | jq -r '.output')
  CR=$(echo "$row" | jq -r '.cache_read')
  CC=$(echo "$row" | jq -r '.cache_creation')
  COST=$(calc_cost "$MODEL" "$IN" "$OUT" "$CR" "$CC")
  SESSION_COST=$(awk -v a="$SESSION_COST" -v b="$COST" 'BEGIN { printf "%.6f", a+b }')
done < <(echo "$USAGE_JSON" | jq -c '.[]' 2>/dev/null)

# 일일 누적 (date 키로 파일 분리)
TODAY=$(date -u +%Y-%m-%d)
DAILY_FILE="${BUDGET_DIR}/daily-${TODAY}.txt"
DAILY_PREV=$(cat "$DAILY_FILE" 2>/dev/null || echo "0")
# session 단위 비용은 매 호출마다 덮어쓰므로, daily는 sessions[*].cost의 sum이 정확
# 단순화: 세션 파일 별도 보관 후 daily 재계산
SESSION_FILE="${BUDGET_DIR}/session-${SESSION_ID}.txt"
echo "$SESSION_COST" > "$SESSION_FILE"

DAILY_COST=$(awk 'BEGIN { s=0 } { s+=$1 } END { printf "%.6f", s }' "${BUDGET_DIR}"/session-*.txt 2>/dev/null | tail -1)
[ -z "$DAILY_COST" ] && DAILY_COST="$SESSION_COST"
echo "$DAILY_COST" > "$DAILY_FILE"

# 임계치 체크
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SESSION_PCT=$(awk -v c="$SESSION_COST" -v l="$SESSION_LIMIT" 'BEGIN { printf "%.0f", (c/l)*100 }')
DAILY_PCT=$(awk -v c="$DAILY_COST" -v l="$DAILY_LIMIT" 'BEGIN { printf "%.0f", (c/l)*100 }')

# JSONL log
echo "{\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\",\"session_cost_usd\":$SESSION_COST,\"daily_cost_usd\":$DAILY_COST,\"session_limit_usd\":$SESSION_LIMIT,\"daily_limit_usd\":$DAILY_LIMIT,\"session_pct\":$SESSION_PCT,\"daily_pct\":$DAILY_PCT}" >> "$BUDGET_LOG"

# 80% 도달 경고
if [ "$SESSION_PCT" -ge 80 ] || [ "$DAILY_PCT" -ge 80 ]; then
  echo "⚠️ Budget warning: session ${SESSION_PCT}% (\$${SESSION_COST}/\$${SESSION_LIMIT}), daily ${DAILY_PCT}% (\$${DAILY_COST}/\$${DAILY_LIMIT})" >&2
fi

# 100% 초과 시 block
SESSION_OVER=$(awk -v c="$SESSION_COST" -v l="$SESSION_LIMIT" 'BEGIN { print (c >= l) ? 1 : 0 }')
DAILY_OVER=$(awk -v c="$DAILY_COST" -v l="$DAILY_LIMIT" 'BEGIN { print (c >= l) ? 1 : 0 }')

if [ "$SESSION_OVER" = "1" ] || [ "$DAILY_OVER" = "1" ]; then
  REASON="Budget exceeded: session \$${SESSION_COST}/\$${SESSION_LIMIT}, daily \$${DAILY_COST}/\$${DAILY_LIMIT}"
  echo "{\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\",\"action\":\"BUDGET_EXCEEDED\",\"reason\":\"$REASON\"}" >> "$BUDGET_LOG"

  if [ "$MODE" = "block" ]; then
    # PreToolUse hook용 block JSON 출력
    echo "{\"decision\":\"block\",\"reason\":\"$REASON. Set CLAUDE_BUDGET_MODE=warn to disable, or raise CLAUDE_BUDGET_SESSION_USD / CLAUDE_BUDGET_DAILY_USD.\"}"
    exit 2
  else
    echo "🚨 $REASON (MODE=warn, not blocking)" >&2
  fi
fi

exit 0
