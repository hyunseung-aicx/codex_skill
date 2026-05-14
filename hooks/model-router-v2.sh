#!/usr/bin/env bash
# model-router-v2.sh — 연구 기반 정밀 모델 라우팅 (Harness v6.1 P1+)
#
# 학술/산업 SOTA 근거:
#   - Anthropic Three-Agent Harness (2026.03): Planner=Opus, Generator=Sonnet, Evaluator=Haiku
#   - Terminal Bench 2.0 (LangChain): high=63.6%, xhigh=53.9%, Sandwich=66.5%
#   - SelfBudgeter (arXiv 2505.11274): 토큰 예산을 사전 예측 → +12.8% 정확도
#   - AgentTTS (arXiv 2508.00890): subtask별 모델·예산 분리 배분
#   - OpenAI Codex dual-tier (2026.04): orchestrator(high) + specialist(xhigh) + utility(medium)
#   - Adaptive TTC (arXiv 2604.14853): per-instance 예산 결정
#
# v1 대비 변경점:
#   1. Complexity score (0~10) 다차원 계산
#   2. (model, reasoning_level) 페어 출력
#   3. Subtask 분해 추천 (complexity ≥ 7)
#   4. Token budget 추정 + 비용 추정
#   5. Plan/Verify subtask에 한정한 xhigh 권장
#   6. Alternatives 제시
#   7. routing-recommendations.jsonl 기록 → 사후 검증 가능
#
# 출력: hookSpecificOutput JSON (UserPromptSubmit)

set -uo pipefail

readonly TRACES_DIR="${HOME}/.claude/traces"
readonly ROUTER_LOG="${TRACES_DIR}/routing-recommendations.jsonl"

mkdir -p "$TRACES_DIR"

[ "${CLAUDE_ROUTER_DISABLE:-0}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || echo '{}')"
SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // "unknown"')"
USER_PROMPT="$(echo "$INPUT" | jq -r '.prompt // .user_message // ""' | head -c 10000)"

[ -z "$USER_PROMPT" ] && exit 0

# ─────────────────────────────────────────────────────────
# 1. Complexity Score 계산 (0~10)
# ─────────────────────────────────────────────────────────

PROMPT_LEN=${#USER_PROMPT}
PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

# 가중치 (학술 자료 + 휴리스틱 기반 초기값)
W_LENGTH_LOG=1.5        # log scale
W_KW_SIMPLE=-1.0        # 단순 키워드 감점
W_KW_COMPLEX=2.0        # 복잡 키워드 가점
W_KW_SECURITY=2.5       # 보안 키워드 가점
W_FILES=0.5             # 언급된 파일당
W_MULTI_FILE=1.5        # 3개+ 파일 시 추가
W_PLANNING_VERB=1.0     # 기획/설계 동사
W_KW_CODING=1.5         # 코딩 작업 동사 (sonnet 권장)
W_SHORT_FLOOR=2.5       # 매우 짧은 prompt에 대한 floor (정보 부족 시 sonnet 추천)

# 단순 키워드 (Haiku로 충분한 작업)
SIMPLE_KW='(typo|rename|format|prettier|comment|whitespace|오타|이름변경|포맷|공백|들여쓰기)'

# 코딩 작업 동사 (Sonnet 권장 — 의미있는 구현 작업)
CODING_KW='(function|method|api|endpoint|component|service|hook|module|class|만들어|구현|작성|추가|create|implement|build|add|write)'

# 복잡 키워드 (Opus 권장)
COMPLEX_KW='(architecture|refactor|migration|redesign|rewrite|design|trade-?off|아키텍처|리팩토링|마이그레이션|재설계|설계|분석)'

# 보안 키워드 (Opus + xhigh 권장)
SECURITY_KW='(security|auth|authentication|authorization|vulnerability|cve|injection|xss|csrf|보안|인증|취약점)'

# 기획/설계 동사 (planning phase 시그널)
PLANNING_KW='(plan|design|architect|propose|recommend|evaluate|trade-off|기획|설계|평가|제안|검토)'

# 키워드 매칭 수
COUNT_SIMPLE=$(echo "$PROMPT_LOWER" | grep -Eo "$SIMPLE_KW" | wc -l | tr -d ' ')
COUNT_COMPLEX=$(echo "$PROMPT_LOWER" | grep -Eo "$COMPLEX_KW" | wc -l | tr -d ' ')
COUNT_SECURITY=$(echo "$PROMPT_LOWER" | grep -Eo "$SECURITY_KW" | wc -l | tr -d ' ')
COUNT_PLANNING=$(echo "$PROMPT_LOWER" | grep -Eo "$PLANNING_KW" | wc -l | tr -d ' ')
COUNT_CODING=$(echo "$PROMPT_LOWER" | grep -Eo "$CODING_KW" | wc -l | tr -d ' ')

# 파일 언급 수 (확장자 패턴 + path 패턴)
FILE_COUNT=$(echo "$USER_PROMPT" | grep -Eo '[a-zA-Z0-9_./-]+\.[a-z]{1,5}' | sort -u | wc -l | tr -d ' ')

# Complexity score 계산 (bash 부동소수 — awk 위임)
SCORE=$(awk -v len="$PROMPT_LEN" \
           -v wl="$W_LENGTH_LOG" \
           -v ws="$W_KW_SIMPLE" \
           -v wc="$W_KW_COMPLEX" \
           -v wsec="$W_KW_SECURITY" \
           -v wf="$W_FILES" \
           -v wmf="$W_MULTI_FILE" \
           -v wpv="$W_PLANNING_VERB" \
           -v wkc="$W_KW_CODING" \
           -v wsf="$W_SHORT_FLOOR" \
           -v cs="$COUNT_SIMPLE" \
           -v cc="$COUNT_COMPLEX" \
           -v csec="$COUNT_SECURITY" \
           -v cpv="$COUNT_PLANNING" \
           -v ck="$COUNT_CODING" \
           -v fc="$FILE_COUNT" \
           'BEGIN {
              len_score = (len > 100) ? wl * log(len / 100) : 0;
              kw_score = (ws * cs) + (wc * cc) + (wsec * csec) + (wpv * cpv) + (wkc * ck);
              file_score = wf * fc + ((fc >= 3) ? wmf : 0);
              total = len_score + kw_score + file_score;
              # 짧은 prompt 보정: 코딩 동사가 있으면 floor 적용 (sonnet 추천)
              if (len < 100 && ck > 0 && total < wsf) total = wsf;
              if (total < 0) total = 0;
              if (total > 10) total = 10;
              printf "%.2f", total
           }')

# ─────────────────────────────────────────────────────────
# 2. 라우팅 결정 (model + reasoning_level)
# ─────────────────────────────────────────────────────────

SCORE_INT=$(echo "$SCORE" | awk '{print int($1)}')

# 기본 라우팅
if [ "$SCORE_INT" -lt 2 ]; then
  REC_MODEL="haiku"
  REC_REASONING="low"
  TIER="utility"
elif [ "$SCORE_INT" -lt 5 ]; then
  REC_MODEL="sonnet"
  REC_REASONING="high"
  TIER="generator"
elif [ "$SCORE_INT" -lt 7 ]; then
  REC_MODEL="opus"
  REC_REASONING="high"
  TIER="planner"
else
  REC_MODEL="opus"
  REC_REASONING="xhigh"  # Plan/Verify subtask 용
  TIER="planner+specialist"
fi

# 보안 작업은 항상 Opus
if [ "$COUNT_SECURITY" -gt 0 ]; then
  REC_MODEL="opus"
  [ "$REC_REASONING" = "low" ] && REC_REASONING="high"
fi

# Subtask 분해 추천 여부
SUBTASK_SPLIT="false"
if [ "$SCORE_INT" -ge 7 ] || [ "$FILE_COUNT" -ge 5 ]; then
  SUBTASK_SPLIT="true"
fi

# ─────────────────────────────────────────────────────────
# 3. Token 예산 추정 (heuristic SelfBudgeter)
# ─────────────────────────────────────────────────────────

# Input: prompt + 평균 system context (40K) + 작업별 가중치
EST_INPUT=$((PROMPT_LEN / 4 + 40000))

# Output: complexity score 비례 (heuristic)
EST_OUTPUT=$(awk -v s="$SCORE" 'BEGIN { printf "%.0f", 500 + s * 1500 }')

# Cost (USD, 2026.05 단가)
case "$REC_MODEL" in
  opus)
    RATE_IN=15.0; RATE_OUT=75.0
    [ "$REC_REASONING" = "xhigh" ] && EST_OUTPUT=$((EST_OUTPUT * 2))
    ;;
  sonnet) RATE_IN=3.0; RATE_OUT=15.0 ;;
  haiku)  RATE_IN=1.0; RATE_OUT=5.0 ;;
esac

EST_COST=$(awk -v i="$EST_INPUT" -v o="$EST_OUTPUT" -v ri="$RATE_IN" -v ro="$RATE_OUT" \
           'BEGIN { printf "%.4f", (i*ri + o*ro) / 1000000 }')

# ─────────────────────────────────────────────────────────
# 4. Subtask 분해 계획 (AgentTTS 패턴)
# ─────────────────────────────────────────────────────────

SUBTASK_PLAN="[]"
if [ "$SUBTASK_SPLIT" = "true" ]; then
  # 기본 3단계 Sandwich (Plan-Impl-Verify)
  SUBTASK_PLAN=$(jq -n '[
    {phase: "plan",     model: "opus",   reasoning: "xhigh", est_tokens: 2500, est_cost_usd: 0.075},
    {phase: "implement", model: "sonnet", reasoning: "high",  est_tokens: 12000, est_cost_usd: 0.225},
    {phase: "verify",   model: "sonnet", reasoning: "high",  est_tokens: 4000, est_cost_usd: 0.075}
  ]')
fi

# ─────────────────────────────────────────────────────────
# 5. Alternatives (한 단계 저렴한 선택)
# ─────────────────────────────────────────────────────────

ALTERNATIVES="[]"
case "$REC_MODEL" in
  opus)
    ALT_COST=$(awk -v i="$EST_INPUT" -v o="$EST_OUTPUT" 'BEGIN { printf "%.4f", (i*3 + o*15) / 1000000 }')
    ALT_DELTA=$(awk -v c="$EST_COST" -v a="$ALT_COST" 'BEGIN { printf "%.0f", ((a-c)/c)*100 }')
    ALTERNATIVES=$(jq -n --arg cost "$ALT_COST" --arg delta "$ALT_DELTA" \
      '[{model: "sonnet", reasoning: "high", est_cost_usd: ($cost|tonumber), cost_delta_pct: ($delta|tonumber)}]')
    ;;
  sonnet)
    ALT_COST=$(awk -v i="$EST_INPUT" -v o="$EST_OUTPUT" 'BEGIN { printf "%.4f", (i*1 + o*5) / 1000000 }')
    ALT_DELTA=$(awk -v c="$EST_COST" -v a="$ALT_COST" 'BEGIN { printf "%.0f", ((a-c)/c)*100 }')
    ALTERNATIVES=$(jq -n --arg cost "$ALT_COST" --arg delta "$ALT_DELTA" \
      '[{model: "haiku", reasoning: "low", est_cost_usd: ($cost|tonumber), cost_delta_pct: ($delta|tonumber)}]')
    ;;
esac

# ─────────────────────────────────────────────────────────
# 6. Reasoning 메시지 (사용자에게 보이는 이유)
# ─────────────────────────────────────────────────────────

REASON_PARTS=""
[ "$PROMPT_LEN" -gt 1000 ] && REASON_PARTS="${REASON_PARTS}긴 prompt(${PROMPT_LEN}자) "
[ "$COUNT_COMPLEX" -gt 0 ] && REASON_PARTS="${REASON_PARTS}복잡 키워드 ${COUNT_COMPLEX}개 "
[ "$COUNT_SECURITY" -gt 0 ] && REASON_PARTS="${REASON_PARTS}보안 키워드 ${COUNT_SECURITY}개 "
[ "$COUNT_SIMPLE" -gt 0 ] && [ -z "$REASON_PARTS" ] && REASON_PARTS="단순 키워드 ${COUNT_SIMPLE}개 "
[ "$FILE_COUNT" -ge 3 ] && REASON_PARTS="${REASON_PARTS}파일 ${FILE_COUNT}개 언급 "
[ -z "$REASON_PARTS" ] && REASON_PARTS="기본값 "

# ─────────────────────────────────────────────────────────
# 7. JSON 출력 + 로그
# ─────────────────────────────────────────────────────────

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

RECOMMENDATION=$(jq -n \
  --arg ts "$TIMESTAMP" \
  --arg sid "$SESSION_ID" \
  --arg model "$REC_MODEL" \
  --arg reasoning "$REC_REASONING" \
  --arg tier "$TIER" \
  --argjson score "$SCORE" \
  --argjson est_in "$EST_INPUT" \
  --argjson est_out "$EST_OUTPUT" \
  --arg est_cost "$EST_COST" \
  --arg subtask "$SUBTASK_SPLIT" \
  --argjson plan "$SUBTASK_PLAN" \
  --argjson alts "$ALTERNATIVES" \
  --arg reason "$REASON_PARTS" \
  '{
    timestamp: $ts,
    session_id: $sid,
    complexity_score: $score,
    recommended: {
      model: $model,
      reasoning_level: $reasoning,
      tier: $tier,
      estimated_input_tokens: $est_in,
      estimated_output_tokens: $est_out,
      estimated_cost_usd: ($est_cost | tonumber)
    },
    reasoning: $reason,
    subtask_split_recommended: ($subtask == "true"),
    subtask_plan: $plan,
    alternatives: $alts
  }')

echo "$RECOMMENDATION" >> "$ROUTER_LOG"

# ─────────────────────────────────────────────────────────
# 8. 사용자에게 컨텍스트 주입 (UserPromptSubmit hookSpecificOutput)
# ─────────────────────────────────────────────────────────

# 기본값(Sonnet/high)이면 silent pass
if [ "$REC_MODEL" = "sonnet" ] && [ "$REC_REASONING" = "high" ] && [ "$SUBTASK_SPLIT" = "false" ]; then
  exit 0
fi

# 사용자에게 보낼 메시지 구성
MSG="🧠 모델 라우팅 v2 추천:"
MSG="$MSG\n  ▸ 모델: ${REC_MODEL} (${REC_REASONING})"
MSG="$MSG\n  ▸ Complexity: ${SCORE}/10"
MSG="$MSG\n  ▸ 예상 비용: \$${EST_COST} (입력 ${EST_INPUT}토큰, 출력 ${EST_OUTPUT}토큰)"
MSG="$MSG\n  ▸ 이유: ${REASON_PARTS}"

if [ "$SUBTASK_SPLIT" = "true" ]; then
  MSG="$MSG\n  ⚠️ 복잡도 7+ — 3단계 분해 권장 (plan→impl→verify), 분해 시 비용 -50% 가능"
fi

if [ "$ALTERNATIVES" != "[]" ]; then
  ALT_MODEL=$(echo "$ALTERNATIVES" | jq -r '.[0].model')
  ALT_DELTA=$(echo "$ALTERNATIVES" | jq -r '.[0].cost_delta_pct')
  MSG="$MSG\n  💡 대안: ${ALT_MODEL} (${ALT_DELTA}% 비용 변화)"
fi

# HookSpecificOutput JSON
jq -n --arg msg "$MSG" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $msg
  }
}'

exit 0
