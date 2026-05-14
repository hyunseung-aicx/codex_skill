# 🔧 scripts/ — 일회성 도우미 스크립트

> **한 줄 요약**: 자주 쓰지 않지만 가끔 필요한 변환·마이그레이션 도구 모음입니다.

---

## 훅과의 차이

| 구분 | 훅 (`hooks/`) | 스크립트 (`scripts/`) |
|------|--------------|-------------------|
| 발동 시점 | 클로드 코드가 **자동** 실행 | 사용자가 **수동** 실행 |
| 빈도 | 매 메시지/도구마다 | 가끔 (마이그레이션, 일괄 변환) |
| 비유 | 자동차 ABS | 자동차 타이어 펌프 |

---

## 이 폴더의 스크립트

### `migrate-to-otel.sh`

**무엇을 하나요?**:
- 기존에 쌓인 추적 로그(`~/.claude/traces/*.jsonl`)를 **OpenTelemetry GenAI 표준 포맷**으로 일괄 변환.

**왜 필요한가요?**:
- 자체 JSONL 포맷은 Datadog·Langfuse 같은 외부 분석 도구에 바로 import 불가.
- 2026.03부터 Datadog가 GenAI semantic conventions native 지원 → 표준화 필수.
- 작년 데이터까지 모두 표준 포맷으로 가져가려면 일괄 변환 필요.

**사용 예제**:

```bash
# 작년 12월 데이터 변환
bash scripts/migrate-to-otel.sh ~/.claude/traces/2025-12.jsonl > /tmp/otel-2025-12.jsonl

# Datadog에 import (OTel collector 사용)
otelcol --config datadog.yaml --input /tmp/otel-2025-12.jsonl

# Langfuse에 import (Langfuse SDK 사용)
python -m langfuse.import --input /tmp/otel-2025-12.jsonl
```

**변환 규칙**:

| 기존 필드 | OTel attribute |
|----------|---------------|
| `tool_name` | `gen_ai.tool.name` |
| `session_id` | `gen_ai.session.id` (+ `trace_id`) |
| `usage.input_tokens` | `gen_ai.usage.input_tokens` |
| `usage.output_tokens` | `gen_ai.usage.output_tokens` |
| `usage.cache_read_input_tokens` | `gen_ai.usage.cache_read_input_tokens` |
| `tool_response.is_error` | `status.code: ERROR` |

---

## 새 스크립트 추가 가이드

이 폴더에 스크립트를 추가하실 때:

1. **WHY 주석** — 파일 상단에 "왜 필요한가" 명시.
2. **사용 예제** — `Usage:` 한 줄 명시 (`#`로 시작).
3. **에러 처리** — `set -euo pipefail` 권장.
4. **출처 인용** — 1차 출처 URL 주석에 포함.

예시 템플릿:
```bash
#!/usr/bin/env bash
# my-new-script.sh — 한 줄 설명
#
# WHY: 왜 필요한가
# 출처: https://...
#
# Usage: bash my-new-script.sh <input-file>

set -euo pipefail
# ...
```

---

## 더 깊이

- [`../hooks/otel-trace-exporter.sh`](../hooks/otel-trace-exporter.sh) — 실시간 OTel 변환 후크 (이 스크립트의 자동 버전)
- [OpenTelemetry GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/)
- [Datadog native OTel GenAI support](https://www.datadoghq.com/blog/llm-otel-semantic-convention/)
