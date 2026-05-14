#!/usr/bin/env bash
# bench-runner.sh — Self-benchmarking loop (Harness v6 P2)
#
# WHY: LangChain Terminal Bench 52.8% → 66.5% 개선의 핵심 — **매 변경 후 89-task 재실행**.
#      자체 self-eval 루프가 없으면 미들웨어 변경이 진짜 효과가 있는지 모름.
#      mini-SWE-agent + 20-task subset이 production-friendly한 nightly bench.
#      출처:
#        - https://www.langchain.com/blog/improving-deep-agents-with-harness-engineering
#        - https://github.com/SWE-agent/mini-swe-agent
#        - https://www.tbench.ai/leaderboard/terminal-bench/2.0
#
# 사용 (cron 권장):
#   0 3 * * *  bash ~/.claude/hooks/bench-runner.sh  # 매일 03:00
#
# 환경변수:
#   CLAUDE_BENCH_TASKS  — Terminal Bench mini 디렉토리 (기본 ~/.claude/bench/mini-tb)
#   CLAUDE_BENCH_MODEL  — bench 모델 (기본 claude-sonnet-4-6)
#   CLAUDE_BENCH_BUDGET — 단일 task 토큰 cap (기본 50000)

set -uo pipefail

readonly TRACES_DIR="${HOME}/.claude/traces"
readonly BENCH_LOG="${TRACES_DIR}/bench-results.jsonl"
readonly BENCH_DIR="${CLAUDE_BENCH_TASKS:-${HOME}/.claude/bench/mini-tb}"
readonly MODEL="${CLAUDE_BENCH_MODEL:-claude-sonnet-4-6}"
readonly BUDGET="${CLAUDE_BENCH_BUDGET:-50000}"
readonly RESULT_DIR="${HOME}/.claude/bench/results/$(date -u +%Y-%m-%d)"

mkdir -p "$TRACES_DIR" "$RESULT_DIR"

# 의존성 체크
if ! command -v jq >/dev/null 2>&1; then
  echo "jq required" >&2
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI required (Claude Code)" >&2
  exit 1
fi

# 벤치 디렉토리 미존재 시 초기화 가이드
if [ ! -d "$BENCH_DIR" ]; then
  cat >&2 <<EOF
⚠️ Benchmark task directory not found: $BENCH_DIR

초기 셋업:
  mkdir -p "$BENCH_DIR"
  # Terminal Bench 2.0 mini subset (20 tasks) 또는 직접 작성한 task 디렉토리 배치
  # 각 task는 한 디렉토리, 내부에 README.md (요구사항) + verify.sh (검증 스크립트)

  예시 구조:
    $BENCH_DIR/
      task-001-rename-vars/
        README.md     # "Rename all 'foo' identifiers to 'bar'"
        verify.sh     # exits 0 if successful
      task-002-add-error-handling/
        ...

샘플 task는 https://github.com/SWE-agent/mini-swe-agent 참조.
EOF
  exit 0
fi

# 결과 누적
TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
START_TIME=$(date -u +%s)

# 각 task 실행
for TASK_DIR in "$BENCH_DIR"/*/; do
  [ ! -d "$TASK_DIR" ] && continue
  TASK_NAME=$(basename "$TASK_DIR")
  TOTAL=$((TOTAL + 1))

  README_FILE="${TASK_DIR}README.md"
  VERIFY_FILE="${TASK_DIR}verify.sh"

  if [ ! -f "$README_FILE" ] || [ ! -f "$VERIFY_FILE" ]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # 워크트리에서 격리 실행
  WORK_DIR="${RESULT_DIR}/${TASK_NAME}"
  cp -r "$TASK_DIR" "$WORK_DIR"

  TASK_PROMPT=$(cat "$README_FILE")
  TASK_START=$(date -u +%s)

  # claude -p headless 실행 (timeout 5분)
  (cd "$WORK_DIR" && timeout 300 claude -p "$TASK_PROMPT" --max-turns 20 --model "$MODEL" --output-format json > result.json 2>&1) || true

  # 검증
  VERIFY_OUTPUT=$(cd "$WORK_DIR" && bash verify.sh 2>&1)
  VERIFY_EXIT=$?

  TASK_END=$(date -u +%s)
  DURATION=$((TASK_END - TASK_START))

  if [ "$VERIFY_EXIT" -eq 0 ]; then
    PASSED=$((PASSED + 1))
    STATUS="PASS"
  else
    FAILED=$((FAILED + 1))
    STATUS="FAIL"
  fi

  echo "[${STATUS}] ${TASK_NAME} (${DURATION}s)"
done

END_TIME=$(date -u +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

# 최종 점수
PASS_RATE=0
if [ "$TOTAL" -gt 0 ]; then
  PASS_RATE=$((PASSED * 100 / TOTAL))
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RESULT_JSON=$(jq -n \
  --arg ts "$TIMESTAMP" \
  --arg model "$MODEL" \
  --argjson total "$TOTAL" \
  --argjson passed "$PASSED" \
  --argjson failed "$FAILED" \
  --argjson skipped "$SKIPPED" \
  --argjson rate "$PASS_RATE" \
  --argjson duration "$TOTAL_DURATION" \
  '{
    timestamp: $ts,
    model: $model,
    total: $total,
    passed: $passed,
    failed: $failed,
    skipped: $skipped,
    pass_rate: $rate,
    duration_sec: $duration
  }')

echo "$RESULT_JSON" >> "$BENCH_LOG"

echo ""
echo "=== Bench Results $(date -u +%Y-%m-%d) ==="
echo "Model:    $MODEL"
echo "Total:    $TOTAL (passed $PASSED, failed $FAILED, skipped $SKIPPED)"
echo "Pass:     ${PASS_RATE}%"
echo "Duration: ${TOTAL_DURATION}s"
echo ""
echo "Log: $BENCH_LOG"
echo "Results: $RESULT_DIR"
