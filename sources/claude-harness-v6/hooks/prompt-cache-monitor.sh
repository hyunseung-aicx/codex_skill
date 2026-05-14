#!/usr/bin/env bash
# prompt-cache-monitor.sh — Anthropic Prompt Caching 모니터링 (Harness v6 P0)
#
# WHY: Anthropic 공식 90% 입력 토큰 절감 + 85ms latency 감소 (https://platform.claude.com/docs/en/build-with-claude/prompt-caching).
#      CLAUDE.md + rules 합산 ~40K 토큰을 매 턴 재처리하면 월 $300, 캐싱 시 월 $58 (-80%).
#      2026 초 5분 TTL 단축으로 야간 무인 운영 시 cache miss 누적 → 1-hour TTL 설정 필수.
#
# 이 후크는 transcript를 파싱하여 cache_read / cache_creation 토큰을 추적하고,
# hit rate < 70% 시 알람한다. Stop 이벤트에서 세션 단위로 집계 권장.
#
# 입력: stdin JSON { session_id, transcript_path, ... }
# 출력: ~/.claude/traces/cache-metrics.jsonl 에 append
# 종료 코드: 0 (advisory, never block)

set -uo pipefail

readonly TRACES_DIR="${HOME}/.claude/traces"
readonly METRICS_FILE="${TRACES_DIR}/cache-metrics.jsonl"
readonly HIT_RATE_THRESHOLD=70  # %
readonly WARN_FILE="${TRACES_DIR}/cache-warnings.jsonl"

mkdir -p "$TRACES_DIR"

# stdin JSON 파싱 (jq 필수)
if ! command -v jq >/dev/null 2>&1; then
  exit 0  # advisory: silent fail
fi

INPUT="$(cat 2>/dev/null || echo '{}')"
SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)"
TRANSCRIPT_PATH="$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)"

# transcript 미존재 시 종료
[ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ] && exit 0

# transcript는 JSONL 형식; 각 line의 usage 필드 집계
# Claude Code transcript의 message 항목에서 usage.cache_* 추출
SUMMARY="$(jq -s '
  map(select(.message.usage != null) | .message.usage) |
  {
    cache_read: (map(.cache_read_input_tokens // 0) | add // 0),
    cache_creation: (map(.cache_creation_input_tokens // 0) | add // 0),
    input: (map(.input_tokens // 0) | add // 0),
    output: (map(.output_tokens // 0) | add // 0),
    turns: length
  }
' "$TRANSCRIPT_PATH" 2>/dev/null || echo '{"cache_read":0,"cache_creation":0,"input":0,"output":0,"turns":0}')"

CACHE_READ=$(echo "$SUMMARY" | jq -r '.cache_read // 0')
CACHE_CREATION=$(echo "$SUMMARY" | jq -r '.cache_creation // 0')
INPUT_TOKENS=$(echo "$SUMMARY" | jq -r '.input // 0')
OUTPUT_TOKENS=$(echo "$SUMMARY" | jq -r '.output // 0')
TURNS=$(echo "$SUMMARY" | jq -r '.turns // 0')

# 총 입력 = cache_read + cache_creation + input
TOTAL_INPUT=$((CACHE_READ + CACHE_CREATION + INPUT_TOKENS))

# Hit rate 계산: cache_read / total_input (0% if no data)
HIT_RATE=0
if [ "$TOTAL_INPUT" -gt 0 ]; then
  HIT_RATE=$((CACHE_READ * 100 / TOTAL_INPUT))
fi

# JSONL append
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "{\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\",\"hit_rate\":$HIT_RATE,\"cache_read\":$CACHE_READ,\"cache_creation\":$CACHE_CREATION,\"input\":$INPUT_TOKENS,\"output\":$OUTPUT_TOKENS,\"turns\":$TURNS}" >> "$METRICS_FILE"

# 임계치 미만 시 경고 (3턴 이상에서만 평가, 초기 노이즈 회피)
if [ "$TURNS" -ge 3 ] && [ "$HIT_RATE" -lt "$HIT_RATE_THRESHOLD" ] && [ "$TOTAL_INPUT" -gt 5000 ]; then
  echo "{\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\",\"warning\":\"cache_hit_rate_low\",\"hit_rate\":$HIT_RATE,\"threshold\":$HIT_RATE_THRESHOLD,\"recommendation\":\"check_settings_cache_control_ttl\"}" >> "$WARN_FILE"
  # statusMessage용 stderr 출력 (Claude Code spinner에 표시)
  echo "⚠️ Prompt cache hit rate ${HIT_RATE}% < ${HIT_RATE_THRESHOLD}% — settings.json의 cache_control 확인" >&2
fi

exit 0
