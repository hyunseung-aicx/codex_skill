#!/usr/bin/env bash
# tool-selector.sh — Dynamic Tool Selection (Harness v6 P1)
#
# WHY: LangChain LLMToolSelectorMiddleware 패턴 (2026.03) —
#      모든 MCP 도구를 매 턴 노출하면 context 토큰 낭비 + tool-thrash 발생.
#      현재 prompt에 필요한 도구만 활성화 권유.
#      출처: https://www.langchain.com/blog/how-middleware-lets-you-customize-your-agent-harness
#
# 동작: UserPromptSubmit 시 prompt 키워드 분석 → 필요한 MCP 서버 카테고리만 추천 출력.
#       실제 도구 활성화는 사용자가 결정 (advisory).
#
# 카테고리:
#   github     — git, PR, issue, commit, code search
#   slack      — message, channel, dm, ping
#   gmail      — email, mail, inbox
#   calendar   — schedule, meeting, event
#   atlassian  — jira, confluence, ticket, page
#   filesystem — 항상 활성 (기본)

set -uo pipefail

readonly TRACES_DIR="${HOME}/.claude/traces"
readonly SELECTOR_LOG="${TRACES_DIR}/tool-selector.jsonl"

mkdir -p "$TRACES_DIR"

[ "${CLAUDE_TOOL_SELECTOR_DISABLE:-0}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || echo '{}')"
SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // "unknown"')"
USER_PROMPT="$(echo "$INPUT" | jq -r '.prompt // .user_message // ""' | head -c 5000)"

[ -z "$USER_PROMPT" ] && exit 0

PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

declare -a SUGGESTED=()

echo "$PROMPT_LOWER" | grep -Eq '(github|pull request|pr |issue|commit|gh )' && SUGGESTED+=("github")
echo "$PROMPT_LOWER" | grep -Eq '(slack|채널|dm|메시지|message|ping)' && SUGGESTED+=("slack")
echo "$PROMPT_LOWER" | grep -Eq '(gmail|email|이메일|메일|inbox)' && SUGGESTED+=("gmail")
echo "$PROMPT_LOWER" | grep -Eq '(calendar|일정|회의|meeting|schedule)' && SUGGESTED+=("calendar")
echo "$PROMPT_LOWER" | grep -Eq '(jira|confluence|atlassian|ticket|페이지)' && SUGGESTED+=("atlassian")
echo "$PROMPT_LOWER" | grep -Eq '(notion|노션)' && SUGGESTED+=("notion")
echo "$PROMPT_LOWER" | grep -Eq '(linear)' && SUGGESTED+=("linear")

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SUGGESTED_JSON=$(printf '%s\n' "${SUGGESTED[@]:-}" | jq -R . | jq -s . 2>/dev/null || echo '[]')

echo "{\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\",\"suggested_categories\":$SUGGESTED_JSON}" >> "$SELECTOR_LOG"

# 5+ 카테고리 추천 시 경고 (너무 광범위)
if [ "${#SUGGESTED[@]}" -gt 4 ]; then
  echo "🛠️ Tool selector: ${#SUGGESTED[@]} MCP categories detected — context bloat 위험. 작업을 분할 고려." >&2
fi

# 0개면 silent pass
[ "${#SUGGESTED[@]}" -eq 0 ] && exit 0

# Advisory context injection
CATEGORIES=$(IFS=,; echo "${SUGGESTED[*]}")
CONTEXT_MSG="🛠️ Tool selector: MCP 카테고리 $CATEGORIES 가 필요해 보입니다. 사용하지 않을 카테고리는 deniedMcpServers로 차단 시 context 절감."

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "$CONTEXT_MSG"
  }
}
EOF

exit 0
