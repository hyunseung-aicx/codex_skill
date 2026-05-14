#!/usr/bin/env bash
# routing-accuracy-tracker.sh — 라우팅 정확도 사후 검증 (Harness v6.1)
#
# WHY: model-router-v2가 추천한 모델 vs 실제 사용된 모델 비교 →
#      라우팅 정확도 측정 + drift 감지.
#      LangChain self-eval 패턴 (89-task 재실행으로 미들웨어 변경 검증).
#
# 동작: PostToolUse async — transcript의 실제 model 필드를 routing-recommendations와 매칭.
#       routing-accuracy.jsonl 에 누적.
#
# 사용 (수동):
#   bash routing-accuracy-tracker.sh report   # 7일 누적 리포트 출력

set -uo pipefail

readonly TRACES_DIR="${HOME}/.claude/traces"
readonly RECS_LOG="${TRACES_DIR}/routing-recommendations.jsonl"
readonly ACCURACY_LOG="${TRACES_DIR}/routing-accuracy.jsonl"

mkdir -p "$TRACES_DIR"

# Report 모드
if [ "${1:-}" = "report" ]; then
  if [ ! -f "$ACCURACY_LOG" ]; then
    echo "아직 데이터가 없습니다. 셋업 적용 후 7일+ 누적되면 다시 시도하세요."
    exit 0
  fi

  echo "=== Routing Accuracy Report (최근 7일) ==="
  jq -s '
    [.[] | select(.timestamp > (now - 7*86400 | strftime("%Y-%m-%dT%H:%M:%SZ")))] |
    {
      total: length,
      exact_match: ([.[] | select(.match == "exact")] | length),
      partial_match: ([.[] | select(.match == "partial")] | length),
      mismatch: ([.[] | select(.match == "mismatch")] | length)
    } |
    . + {
      accuracy_pct: (if .total > 0 then (.exact_match * 100 / .total) else 0 end)
    }
  ' "$ACCURACY_LOG"
  exit 0
fi

# Hook 모드 (PostToolUse)
command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || echo '{}')"
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')

[ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ] && exit 0
[ ! -f "$RECS_LOG" ] && exit 0

# 이 세션의 최근 추천 가져오기
RECENT_REC=$(grep -F "\"session_id\":\"$SESSION_ID\"" "$RECS_LOG" | tail -1)
[ -z "$RECENT_REC" ] && exit 0

REC_MODEL=$(echo "$RECENT_REC" | jq -r '.recommended.model // ""')
[ -z "$REC_MODEL" ] && exit 0

# transcript에서 실제 사용된 모델 추출
ACTUAL_MODEL=$(jq -s '
  [.[] | select(.message.model != null) | .message.model] |
  if length > 0 then .[-1] else "" end
' "$TRANSCRIPT_PATH" 2>/dev/null | tr -d '"' | head -c 50)

[ -z "$ACTUAL_MODEL" ] && exit 0

# 매칭 분류
MATCH="mismatch"
if echo "$ACTUAL_MODEL" | grep -q "$REC_MODEL"; then
  MATCH="exact"
elif echo "$ACTUAL_MODEL" | grep -Eq "(opus|sonnet|haiku)"; then
  # 같은 패밀리지만 다른 tier
  MATCH="partial"
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "{\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\",\"recommended\":\"$REC_MODEL\",\"actual\":\"$ACTUAL_MODEL\",\"match\":\"$MATCH\"}" >> "$ACCURACY_LOG"

exit 0
