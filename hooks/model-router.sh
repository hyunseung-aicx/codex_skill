#!/usr/bin/env bash
# model-router.sh — 자동 모델 라우팅 (Harness v6 P1)
#
# WHY: Reasoning Sandwich를 수동 매핑으로만 유지 시 비효율.
#      hybrid routing 37-87% cost reduction (SciForce, vLLM Semantic Router 2026.03).
#      Anthropic Three-Agent Harness가 모델별 분기를 1st-party 채택.
#      출처:
#        - https://www.langchain.com/blog/how-middleware-lets-you-customize-your-agent-harness
#        - https://www.redhat.com/en/blog/bringing-intelligent-efficient-routing-open-source-ai-vllm-semantic-router
#
# 동작: UserPromptSubmit 시 prompt 길이 + 키워드 + 변경 파일 패턴으로 추천 모델 출력 (advisory).
#       실제 모델 전환은 사용자가 /model 또는 statusMessage 보고 결정.
#
# 라우팅 규칙:
#   - 짧은 prompt (<200chars) + 단순 키워드 (typo, rename, format)         → Haiku
#   - 설계/리팩토링 키워드 (architecture, refactor, migration, design)      → Opus
#   - 그 외 일반 코드 작업                                                   → Sonnet
#
# 환경변수:
#   CLAUDE_ROUTER_DISABLE = 1 비활성화
#   CLAUDE_ROUTER_STRICT  = 1 strict mode (statusMessage로 강하게 권유)

set -uo pipefail

readonly TRACES_DIR="${HOME}/.claude/traces"
readonly ROUTER_LOG="${TRACES_DIR}/model-router.jsonl"

mkdir -p "$TRACES_DIR"

[ "${CLAUDE_ROUTER_DISABLE:-0}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || echo '{}')"
SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // "unknown"')"
USER_PROMPT="$(echo "$INPUT" | jq -r '.prompt // .user_message // ""' | head -c 5000)"

[ -z "$USER_PROMPT" ] && exit 0

PROMPT_LEN=${#USER_PROMPT}
PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

# 키워드 매칭
SIMPLE_KW='(typo|rename|format|prettier|comment|whitespace|오타|이름변경|포맷)'
COMPLEX_KW='(architecture|refactor|migration|redesign|rewrite|design|아키텍처|리팩토링|마이그레이션|재설계|설계)'
SECURITY_KW='(security|auth|authentication|authorization|vulnerability|보안|인증|취약점)'

RECOMMENDED="sonnet"
REASON="default"

if [ "$PROMPT_LEN" -lt 200 ] && echo "$PROMPT_LOWER" | grep -Eq "$SIMPLE_KW"; then
  RECOMMENDED="haiku"
  REASON="short_prompt_simple_task"
elif echo "$PROMPT_LOWER" | grep -Eq "$COMPLEX_KW"; then
  RECOMMENDED="opus"
  REASON="design_or_refactor"
elif echo "$PROMPT_LOWER" | grep -Eq "$SECURITY_KW"; then
  RECOMMENDED="opus"
  REASON="security_sensitive"
elif [ "$PROMPT_LEN" -gt 2000 ]; then
  RECOMMENDED="opus"
  REASON="long_complex_prompt"
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "{\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\",\"prompt_len\":$PROMPT_LEN,\"recommended\":\"$RECOMMENDED\",\"reason\":\"$REASON\"}" >> "$ROUTER_LOG"

# Advisory context injection (UserPromptSubmit hookSpecificOutput)
# 실제 모델 전환은 사용자 결정 — 컨텍스트로만 주입
if [ "$RECOMMENDED" != "sonnet" ]; then
  CONTEXT_MSG="🤖 Model router 추천: ${RECOMMENDED} (이유: ${REASON}). 필요 시 /model 로 전환."
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "$CONTEXT_MSG"
  }
}
EOF
fi

exit 0
