#!/usr/bin/env bash
# migrate-to-otel.sh — 기존 trace JSONL을 OTel GenAI 형식으로 일괄 변환
#
# 사용:
#   ./migrate-to-otel.sh ~/.claude/traces/2026-05-14.jsonl > otel-2026-05-14.jsonl
#
# 변환 규칙:
#   tool_name              → attributes."gen_ai.tool.name"
#   session_id             → attributes."gen_ai.session.id"
#   usage.input_tokens     → attributes."gen_ai.usage.input_tokens"
#   tool_response.is_error → status.code = ERROR

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <input.jsonl>" >&2
  exit 1
fi

INPUT="$1"
[ ! -f "$INPUT" ] && { echo "File not found: $INPUT" >&2; exit 1; }

jq -c '
  {
    timestamp: (.timestamp // (now | strftime("%Y-%m-%dT%H:%M:%SZ"))),
    trace_id: (.session_id // "unknown"),
    span_id: (.tool_use_id // ((.timestamp // "0") + "-" + (.tool_name // "x") | @base64 | .[0:16])),
    name: ("execute_tool " + (.tool_name // "unknown")),
    kind: "INTERNAL",
    status: { code: (if (.tool_response.is_error // false) then "ERROR" else "OK" end) },
    attributes: ({
      "gen_ai.operation.name": "execute_tool",
      "gen_ai.system": "anthropic",
      "gen_ai.tool.name": .tool_name,
      "gen_ai.tool.type": "function",
      "gen_ai.session.id": .session_id,
      "gen_ai.usage.input_tokens": (.usage.input_tokens // null),
      "gen_ai.usage.output_tokens": (.usage.output_tokens // null),
      "gen_ai.usage.cache_read_input_tokens": (.usage.cache_read_input_tokens // null)
    } | with_entries(select(.value != null)))
  }
' "$INPUT"
