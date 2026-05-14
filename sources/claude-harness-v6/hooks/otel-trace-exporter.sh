#!/usr/bin/env bash
# otel-trace-exporter.sh — OpenTelemetry GenAI semantic conventions 변환 (Harness v6 P2)
#
# WHY: 자체 JSONL 포맷은 Langfuse/LangSmith/Datadog 연동 시 매핑 비용 발생.
#      2026.03 Datadog가 GenAI semantic conventions native 지원 — 표준화 가속.
#      미래 마이그레이션 비용을 지금 막아둔다.
#      출처:
#        - https://opentelemetry.io/docs/specs/semconv/gen-ai/
#        - https://www.datadoghq.com/blog/llm-otel-semantic-convention/
#
# 동작: PostToolUse에서 도구 호출을 OTel `gen_ai.*` attribute 형식 JSONL로 변환.
#       기존 trace-logger.sh와 병행 운영 (점진 마이그레이션).
#
# 출력: ~/.claude/traces/otel-spans.jsonl
#   각 라인은 OTel-style span JSON (gen_ai.operation.name, gen_ai.agent.name, gen_ai.usage.*)

set -uo pipefail

readonly TRACES_DIR="${HOME}/.claude/traces"
readonly OTEL_LOG="${TRACES_DIR}/otel-spans.jsonl"

mkdir -p "$TRACES_DIR"

command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || echo '{}')"

# OTel GenAI semantic convention 매핑 (2026.04 stable)
# https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/
#
# Required:
#   gen_ai.operation.name   — "execute_tool" (도구 호출)
#   gen_ai.system           — "anthropic"
# Conditional:
#   gen_ai.agent.name       — sub-agent 이름 (있을 때)
#   gen_ai.tool.name        — 도구 이름
#   gen_ai.tool.type        — "function" | "extension"
#   gen_ai.usage.input_tokens / output_tokens / cache_read_input_tokens

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)"
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

[ -z "$TOOL_NAME" ] && exit 0

# Span ID 생성 (간이 — 실제 OTel은 16-byte hex)
SPAN_ID=$(shasum -a 256 <<< "$TIMESTAMP-$SESSION_ID-$TOOL_NAME-$$" | cut -c1-16)
TRACE_ID="$SESSION_ID"

# tool_response가 있으면 status, 없으면 unknown
STATUS=$(echo "$INPUT" | jq -r '
  if .tool_response.is_error == true then "ERROR"
  elif .tool_response then "OK"
  else "UNSET" end
')

# OTel span JSON 작성
jq -n \
  --arg ts "$TIMESTAMP" \
  --arg trace_id "$TRACE_ID" \
  --arg span_id "$SPAN_ID" \
  --arg tool "$TOOL_NAME" \
  --arg status "$STATUS" \
  --argjson input "$INPUT" \
  '{
    timestamp: $ts,
    trace_id: $trace_id,
    span_id: $span_id,
    name: ("execute_tool " + $tool),
    kind: "INTERNAL",
    status: { code: $status },
    attributes: {
      "gen_ai.operation.name": "execute_tool",
      "gen_ai.system": "anthropic",
      "gen_ai.tool.name": $tool,
      "gen_ai.tool.type": "function",
      "gen_ai.session.id": ($input.session_id // "unknown"),
      "gen_ai.agent.name": ($input.agent_name // null)
    } | with_entries(select(.value != null))
  }' >> "$OTEL_LOG"

exit 0
