#!/bin/bash
# shellcheck shell=bash
# PostToolUseFailure: Junior-friendly error context aggregator
# 어떤 도구든 실패하면 자동으로 "재현·분석·트레이드오프" 컨텍스트를 수집한다.
# failure-explainer.sh와 짝 — explainer는 Bash 한정, 이건 모든 tool 대상.
#
# 출력: 추가 reason 필드로 컨텍스트 주입 → 다음 단계에서 AI가 활용
#
# 주니어가 AI와 함께 디버깅할 때 흔한 마찰 4가지를 해소:
#   1. "어떻게 재현하지?" → 실패 명령 + cwd + git HEAD를 한 블록에 묶어줌
#   2. "어떤 로그를 봐야 하지?" → 최근 30분 내 변경된 파일 list
#   3. "fix 옵션이 뭐가 있지?" → 즉시 패치 / 우회 / 근본 fix 3안 비교 prompt
#   4. "혼자 끙끙대지 말라" → 같은 실패 3회+ 시 debugger agent 위임 강제

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
ERROR=$(echo "$INPUT" | jq -r '.error // .tool_output // .stderr // "unknown error"' 2>/dev/null | head -c 800)

# Bash는 failure-explainer.sh가 처리하므로 여기선 비-Bash 도구만
if [ "$TOOL_NAME" = "Bash" ]; then
  exit 0
fi

# Trace
LOG_DIR="${HOME}/.claude/traces"
mkdir -p "$LOG_DIR"
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"ToolFailure\",\"tool\":\"${TOOL_NAME}\",\"session\":\"${CLAUDE_SESSION_ID:-unknown}\"}" >> "${LOG_DIR}/tool-failures.jsonl"

# 세션 누적 카운트
SESSION_KEY="${CLAUDE_SESSION_ID:-$$}"
COUNTER_FILE="${TMPDIR:-/tmp}/claude-tool-fail-${SESSION_KEY}-${TOOL_NAME}"
COUNT=0
[ -f "$COUNTER_FILE" ] && COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# 컨텍스트 수집 (재현·로그·트레이드오프)
CWD=$(pwd 2>/dev/null || echo "?")
GIT_HEAD=""
GIT_STATUS=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_HEAD=$(git log --oneline -1 2>/dev/null | head -c 80)
  GIT_STATUS=$(git status --short 2>/dev/null | head -5 | tr '\n' ';')
fi

# 최근 30분 내 수정된 src/ 파일 (가장 가능성 있는 원인)
RECENT_FILES=""
if [ -d "src" ]; then
  RECENT_FILES=$(find src -type f -newermt "30 minutes ago" 2>/dev/null | head -5 | tr '\n' ' ')
fi

# 표준 가이드 메시지 (stderr로 → AI가 다음 turn에서 인식)
{
  echo ""
  echo "🔍 [error-context-collector] ${TOOL_NAME} 실패 #${COUNT}"
  echo "  cwd: ${CWD}"
  [ -n "$GIT_HEAD" ] && echo "  HEAD: ${GIT_HEAD}"
  [ -n "$GIT_STATUS" ] && echo "  modified: ${GIT_STATUS}"
  [ -n "$RECENT_FILES" ] && echo "  recently changed: ${RECENT_FILES}"
  echo ""
  echo "  ── 다음 단계 권장 (5단 분해) ──"
  echo "  1. WHAT  : 에러 메시지 핵심 1줄 (위 ERROR 참고)"
  echo "  2. WHERE : file:line 정확히 (스택 트레이스 또는 위 modified 목록)"
  echo "  3. WHY   : 왜? 2~3단계 추적 (단순 증상 ≠ 근본원인)"
  echo "  4. FIX 트레이드오프:"
  echo "     (A) 즉시 패치 — 현 동작만 막음, 빠름, 부채 가능"
  echo "     (B) 우회      — feature flag / fallback, 중간"
  echo "     (C) 근본 fix  — 원인 제거, 느림, 가장 안전"
  echo "     → 시간·위험·범위 비교 후 1개 선택"
  echo "  5. PREVENT: 같은 실수 막을 훅·테스트·규칙"
} >&2

# 3회 이상 실패 시 강제 에스컬레이션
if [ "$COUNT" -ge 3 ]; then
  {
    echo ""
    echo "🚨 ${TOOL_NAME} 실패 ${COUNT}회 누적 — 혼자 끙끙대지 말 것!"
    echo "   다음 행동: Agent({subagent_type:'debugger', prompt:'<위 5단 분해와 함께>'})"
    echo "   또는 사용자에게 '도와주세요' 요청 (실패는 학습 자료)"
    echo ""
  } >&2
fi

exit 0
