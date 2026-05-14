# 🛡️ hooks/ — 훅 (자동 안전장치)

> **한 줄 요약**: 클로드 코드의 자동차 ABS·에어백·차선이탈경보 같은 자동 안전장치 모음입니다.

---

## 훅이 뭔가요?

**훅(hook)** 은 클로드 코드가 작업할 때 **특정 순간에 자동으로 끼어드는 작은 스크립트**입니다. 사용자가 "이거 해줘"라고 명령하지 않아도, 정해진 이벤트가 발생하면 알아서 실행됩니다.

### 자동차 비유

| 자동차 | 훅 |
|--------|----|
| 시동 거는 순간 → 안전벨트 미착용 경고 | `SessionStart` 이벤트 → 환경 점검 |
| 액셀 밟기 직전 → ABS 작동 가능 상태 확인 | `PreToolUse` 이벤트 → 위험 명령 차단 |
| 차선 이탈 → 경보 울림 | `PostToolUse` 이벤트 → 같은 동작 5번 반복 시 알림 |
| 시동 끄기 직전 → "헤드라이트 꺼졌나요?" 점검 | `Stop` 이벤트 → 작업 결과 평가 |

### 왜 필요한가요?

훅이 없으면 다음 위험이 있습니다:

1. **비용 폭주** — $47,000 / 11일 실제 사고 사례 (2026.03, Anhaia)
2. **무한 루프** — 두 에이전트가 서로 코드를 되돌리는 ping-pong
3. **테스트 조작** — 통과시키려고 테스트를 약화시키는 패턴
4. **민감 정보 유출** — API 키, 비밀번호가 커밋에 포함
5. **위험 명령** — `rm -rf /`, `git push --force` 같은 비가역 동작

훅은 이런 사고를 **사람이 매번 점검하지 않아도** 자동으로 막아줍니다.

---

## 이 폴더의 훅 9개 — 한눈에

| # | 후크 파일 | 언제 발동 | 핵심 효과 |
|---|---------|---------|---------|
| 1 | `prompt-cache-monitor.sh` | 작업 종료 시 | 캐시 활용률 측정, 70% 미만 시 경고 |
| 2 | `budget-gate.sh` | 도구 사용 직전 | USD 누적 한도 초과 시 자동 차단 |
| 3 | `llm-judge.sh` | 작업 종료 시 | LLM이 결과 평가 (Spotify Honk 25% veto 패턴) |
| 4 | `tool-hash-dedup.sh` | 도구 사용 후 | 같은 동작 5번 반복 감지 |
| 5 | `model-router-v2.sh` | 사용자 메시지 입력 시 | Haiku/Sonnet/Opus 자동 추천 (학술 기반) |
| 6 | `tool-selector.sh` | 사용자 메시지 입력 시 | 필요한 MCP 도구 카테고리 추천 |
| 7 | `otel-trace-exporter.sh` | 도구 사용 후 | OpenTelemetry 표준 포맷 기록 |
| 8 | `routing-accuracy-tracker.sh` | 도구 사용 후 | 라우팅 추천 vs 실제 사용 비교 (사후 검증) |
| 9 | `bench-runner.sh` | 수동 또는 cron | 매일 밤 미니 벤치마크 자동 실행 |

---

## 각 후크 상세 — 비유와 예제

### 1. `prompt-cache-monitor.sh` — "연비 측정기"

**비유**: 자동차의 연비 모니터링. 평소엔 조용하지만 평균 연비가 떨어지면 "엔진 점검하세요" 알림.

**무엇을 하나요?**:
- 클로드 API의 prompt cache가 얼마나 활용되는지 추적합니다.
- 매 세션 종료 시 `cache_read_input_tokens` / 전체 입력 토큰 비율을 계산합니다.
- 70% 미만이면 경고 (캐시 설정이 잘못됐을 가능성).

**왜 중요한가요?**:
- Anthropic 공식 데이터: prompt caching으로 **입력 토큰 90% 절감, latency -85ms**.
- 캐시 활성화 안 하면 매 메시지마다 CLAUDE.md + rules(약 40K 토큰)를 다시 처리 → 월 $300 추가 비용.

**예제 출력**:
```
⚠️ Prompt cache hit rate 35% < 70% — settings.json의 cache_control 확인
```

---

### 2. `budget-gate.sh` — "월 외식비 한도 알림"

**비유**: 가계부 앱이 "이번 달 외식 한도 10만 원 초과"라고 알리는 것. 단, **자동으로 결제도 막아줍니다**.

**무엇을 하나요?**:
- 매 도구 사용 직전에 누적 비용 계산.
- 세션당 $5, 하루 $20 한도 도달 시 **자동 차단**.
- 80% 도달 시 경고만 (멈추진 않음).

**왜 중요한가요?**:
- 실제 사고 사례: **$47,000 / 11일** (Anhaia 2026.03), **$4,200 / 63시간** (Sattyam Jain 2026.02).
- 토큰 80% 가드만으론 누적 ping-pong 못 잡습니다 — 달러 단위 enforcement 필요.

**예제 출력 (경고)**:
```
⚠️ Budget warning: session 80% ($4.02/$5), daily 23% ($4.61/$20)
```

**예제 출력 (차단)**:
```
🚨 Budget exceeded: session $5.12/$5, daily $5.71/$20
❌ Tool call blocked.
```

**환경변수로 조절**:
```bash
export CLAUDE_BUDGET_SESSION_USD=10   # 세션 한도 상향
export CLAUDE_BUDGET_DAILY_USD=50      # 일일 한도 상향
export CLAUDE_BUDGET_MODE=warn         # 차단 대신 경고만
```

---

### 3. `llm-judge.sh` — "퇴근 전 자기 검토"

**비유**: 회사에서 퇴근 직전 매니저가 "오늘 한 일 정리해서 보여줘" 요청. 자기 채점 금지 — 다른 사람이 봐줘야 객관적.

**무엇을 하나요?**:
- 작업 종료 시 `git diff HEAD` + 사용자 원래 요청을 추출합니다.
- Haiku 모델에게 "이 diff가 사용자 요청을 충실히 구현했는가?" 평가 요청.
- 답이 BLOCK이면 차단 (또는 경고만).

**검사 항목 5가지**:
1. 테스트를 약화시키지 않았는가? (`toBeTruthy()` 로 바꾸기)
2. catch 블록 비워두지 않았는가?
3. dead code, TODO 그대로 두지 않았는가?
4. 보안 이슈 (하드코딩 비밀번호 등)?
5. 사용자 요청을 옆길로 새지 않았는가?

**왜 중요한가요?**:
- Spotify Engineering 사례 (2025.12): LLM judge가 **1,500+ PR 자동화 세션의 25%를 veto**.
- 그중 절반은 self-correct로 살아남음 → 회귀 방지에 결정적.

**예제 출력**:
```
🚨 LLM judge would BLOCK (mode=warn): Tests were weakened with toBeTruthy
   Concerns:
   - foo.test.ts:42 toBe(value) → toBeTruthy() 변경됨
   - bar.test.ts:18 expect.assert 제거됨
```

**비용**: 세션당 1회 Haiku 호출, 약 $0.001.

---

### 4. `tool-hash-dedup.sh` — "GPS 같은 곳 돌고 있어요"

**비유**: 자동차 GPS가 "같은 자리에서 5번 후진하셨네요. 다른 길로?" 라고 묻는 것.

**무엇을 하나요?**:
- 매 도구 사용 후 `sha256(tool_name + tool_input)` 계산.
- 같은 hash 5번 반복 시 경고 또는 차단.

**왜 중요한가요?**:
- $47K 사고 패턴: 에이전트 A가 X 만들면 에이전트 B가 되돌리는 ping-pong.
- 파일 편집 횟수만 보는 기존 후크는 못 잡음 — **tool-input 자체의 hash 중복**이 본질 시그널.

**예제 출력**:
```
🔄 Tool ping-pong detected: Edit repeated 5 times. Consider rethinking approach.
```

---

### 5. `model-router-v2.sh` — "일의 크기에 맞는 사람 매칭"

**비유**: 회사에서 "이건 인턴이 하면 됨", "이건 시니어가 해야 함", "이건 임원 결정 필요"를 자동 분류해주는 시스템.

**무엇을 하나요?**:
- 사용자 prompt 분석 → **Complexity score (0~10)** 계산.
- 점수에 따라 Haiku / Sonnet / Opus 추천.
- 예상 토큰 / 비용 미리 계산.
- 복잡도 7+ 시 **3단계 분해 권장** (plan→implement→verify).

**왜 중요한가요?**:
- 학술 근거:
  - **Anthropic Three-Agent Harness** (2026.03) — Planner=Opus, Generator=Sonnet, Evaluator=Haiku
  - **Terminal Bench 2.0**: high(63.6%) > xhigh(53.9%) — 모든 단계 xhigh는 손해
  - **SelfBudgeter** (arXiv 2505.11274) — 토큰 예산 사전 예측 → +12.8% 정확도
  - **AgentTTS** (arXiv 2508.00890) — subtask별 다른 모델 사용

**예제 출력 (복잡 작업)**:
```
🧠 모델 라우팅 v2 추천:
  ▸ 모델: opus (xhigh)
  ▸ Complexity: 10.0/10
  ▸ 예상 비용: $2.93 (입력 40,027토큰, 출력 31,000토큰)
  ▸ 이유: 복잡 키워드 3개 보안 키워드 3개 파일 5개 언급
  ⚠️ 복잡도 7+ — 3단계 분해 권장, 분해 시 비용 -50% 가능
  💡 대안: sonnet (-80% 비용 변화)
```

상세: [`../docs/MODEL_ROUTING_EVALUATION.md`](../docs/MODEL_ROUTING_EVALUATION.md)

---

### 6. `tool-selector.sh` — "외출 시 필요한 가방만"

**비유**: 등산 갈 때 정장 가방을 안 챙기는 것처럼, 코딩 작업에 Gmail / Slack / Calendar 도구는 불필요.

**무엇을 하나요?**:
- 사용자 prompt 키워드 분석.
- 작업에 필요한 MCP(외부 도구) 카테고리만 추천.
- 사용하지 않을 카테고리는 비활성화 권장 → context 토큰 절감.

**예제 출력**:
```
🛠️ Tool selector: MCP 카테고리 slack,atlassian 가 필요해 보입니다.
   사용하지 않을 카테고리는 deniedMcpServers로 차단 시 context 절감.
```

---

### 7. `otel-trace-exporter.sh` — "표준 양식 운행일지"

**비유**: 운수 회사의 표준 양식 운행일지. 나중에 분석 도구(Datadog/Langfuse)에 import하기 쉬움.

**무엇을 하나요?**:
- 매 도구 호출을 OpenTelemetry GenAI 표준 포맷으로 변환.
- `gen_ai.operation.name`, `gen_ai.tool.name`, `gen_ai.usage.*` 표준 attribute 사용.

**왜 중요한가요?**:
- 2026.03부터 Datadog가 native 지원 — 표준화 빠르게 진행 중.
- 자체 JSONL 포맷은 외부 분석 도구 연동 시 매핑 비용 발생.
- 미래 마이그레이션 비용을 지금 차단.

**예제 출력** (`~/.claude/traces/otel-spans.jsonl`):
```json
{
  "timestamp": "2026-05-14T05:30:42Z",
  "trace_id": "session-abc123",
  "span_id": "f4a8b2c1",
  "name": "execute_tool Edit",
  "attributes": {
    "gen_ai.operation.name": "execute_tool",
    "gen_ai.system": "anthropic",
    "gen_ai.tool.name": "Edit"
  }
}
```

---

### 8. `routing-accuracy-tracker.sh` — "추천 정확도 사후 검증"

**비유**: 매니저가 "내가 추천한 사람이 실제로 잘했나" 사후에 점검하는 것.

**무엇을 하나요?**:
- `model-router-v2`가 추천한 모델 vs 실제 사용된 모델 비교.
- `routing-accuracy.jsonl`에 누적 기록.
- 7일+ 데이터 쌓이면 임계값 자동 튜닝 가능.

**왜 중요한가요?**:
- LangChain Terminal Bench 개선의 핵심 = "매 변경 후 89-task 재실행". 자체 평가 루프 없으면 변경 효과 모름.

**예제 사용**:
```bash
bash hooks/routing-accuracy-tracker.sh report
# {
#   "total": 87,
#   "exact_match": 71,
#   "accuracy_pct": 81.6
# }
```

---

### 9. `bench-runner.sh` — "월 1회 정기 점검"

**비유**: 자동차 정기 점검. 매일 자가 점검은 부담이지만 월 1회는 필요.

**무엇을 하나요?**:
- Terminal Bench mini 20-task을 자동 실행.
- 각 task는 README.md (요구사항) + verify.sh (검증).
- 결과를 `bench-results.jsonl`에 기록.

**왜 중요한가요?**:
- LangChain Terminal Bench 52.8% → 66.5% 개선의 비결 = **매 변경 후 89-task 재실행**.
- 자체 self-eval 없으면 미들웨어 변경이 진짜 효과 있는지 측정 불가.

**권장 사용 (cron)**:
```bash
crontab -e
# 추가:
0 3 * * * /bin/bash $HOME/claude_skill/hooks/bench-runner.sh
```

매일 새벽 3시 자동 실행 → 다음 날 결과 확인 가능.

---

## 훅이 작동하지 않을 때

[`../SETUP_GUIDE_macOS.md`](../SETUP_GUIDE_macOS.md) 9절 (트러블슈팅) 참조.

빠른 점검:
```bash
# 권한 확인
ls -la $CLAUDE_SKILL_DIR/hooks/*.sh
# 모두 -rwxr-xr-x 여야 함

# settings.json 경로 확인
jq -r '.hooks | .. | .command? // empty' ~/.claude/settings.json
# 절대 경로여야 함

# Claude Code 재시작
```

---

## 더 깊이 이해하고 싶다면

- [`../BEGINNERS_GUIDE.md`](../BEGINNERS_GUIDE.md) — 큰 그림 + 터미널 출력 예제
- [`../docs/MODEL_ROUTING_EVALUATION.md`](../docs/MODEL_ROUTING_EVALUATION.md) — model-router v1 → v2 학술 근거
- [`../SETUP_SCORE_2026-05.md`](../SETUP_SCORE_2026-05.md) — 각 후크가 점수에 기여한 정도
- 각 `.sh` 파일 상단 주석에 1차 출처 URL 포함
