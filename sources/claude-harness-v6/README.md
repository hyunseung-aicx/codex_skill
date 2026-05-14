# claude_skill — Claude Code Harness v6 (2026-05)

> **모델은 상수, 변수는 하네스다.**
> LangChain은 같은 모델로 Terminal Bench 2.0에서 52.8% → **66.5% (+13.7pt)** 를 만들었습니다.
> 이 레포는 그 다음 단계 — **Anthropic 2026.04 Three-Agent Harness + Spotify Honk verification loop + Zep temporal memory + OWASP Agentic Top 10 가드레일** 을 Claude Code에 이식한 9가지 개선입니다.

[![Score](https://img.shields.io/badge/score-A%20(92.6%2F100)-success)]() [![From](https://img.shields.io/badge/from-B%2B%20(82.5)-blue)]() [![Delta](https://img.shields.io/badge/Δ-%2B10.1-success)]()

---

## 한눈에 보기

| 영역 | Before (v5) | After (v6) | 변경 |
|------|------------|------------|------|
| 하네스 엔지니어링 | 85 | **93.5** | +8.5 |
| 자율 장기 실행 (Ralph Loop) | 82 | **93** | +11 |
| 멀티에이전트 & 평가 | 87 | **97** | +10 |
| 메모리·학습·컨텍스트 | 76 | **87** | +11 |
| **종합** | **82.5 (B+)** | **92.6 (A)** | **+10.1** |

상세: [SETUP_SCORE_2026-05.md](./SETUP_SCORE_2026-05.md)

---

## 9가지 개선 — 한 줄 요약

| # | 우선순위 | 항목 | 효과 | 출처 |
|---|---------|------|------|------|
| 1 | **P0** | [`prompt-cache-monitor.sh`](./hooks/prompt-cache-monitor.sh) | 입력 토큰 -70~90%, 월 비용 -67~80%, TTFT -30~50% | [Anthropic Prompt Caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) |
| 2 | **P0** | [`budget-gate.sh`](./hooks/budget-gate.sh) | USD 누적 cap, $47K 사고 첫날 차단 | [Anhaia $47K postmortem](https://dev.to/gabrielanhaia/the-agent-that-spent-47k-on-itself-an-autonomous-loop-postmortem-3313) |
| 3 | **P1** | [`llm-judge.sh`](./hooks/llm-judge.sh) | Spotify Honk 25% veto, 회귀 방지 | [Spotify Honk](https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3) |
| 4 | **P1** | [`tool-hash-dedup.sh`](./hooks/tool-hash-dedup.sh) | Agent ping-pong 5회+ 차단 | [Anhaia case analysis](https://dev.to/gabrielanhaia/the-agent-that-spent-47k-on-itself-an-autonomous-loop-postmortem-3313) |
| 5 | **P1** | [`model-router.sh`](./hooks/model-router.sh) + [`tool-selector.sh`](./hooks/tool-selector.sh) | Dynamic Reasoning Sandwich, hybrid routing 37~87% cost ↓ | [LangChain Middleware](https://www.langchain.com/blog/how-middleware-lets-you-customize-your-agent-harness) |
| 6 | **P2** | [`memory-schema/`](./memory-schema/) (Zep 패턴) | Temporal metadata, LongMemEval +14.8pt 패턴 | [Zep arXiv 2501.13956](https://arxiv.org/abs/2501.13956) |
| 7 | **P2** | [`agents/judge-agent.md`](./agents/judge-agent.md) | Agent-as-a-Judge, 24 → 25 agents | [arXiv 2508.02994](https://arxiv.org/html/2508.02994v1) |
| 8 | **P2** | [`otel-trace-exporter.sh`](./hooks/otel-trace-exporter.sh) + [`migrate-to-otel.sh`](./scripts/migrate-to-otel.sh) | Datadog/Langfuse 호환 (2026.03 표준) | [OTel GenAI Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/) |
| 9 | **P2** | [`bench-runner.sh`](./hooks/bench-runner.sh) | Nightly Terminal Bench mini 20-task | [LangChain Bench](https://www.langchain.com/blog/improving-deep-agents-with-harness-engineering) |

---

## 디렉토리 구조

```
claude_skill/
├── README.md                       # 이 문서
├── SETUP_GUIDE_macOS.md            # 맥북 적용 가이드 (전역/커스텀 경로)
├── SETUP_SCORE_2026-05.md          # 점수 평가 (Before/After)
├── .gitignore
│
├── hooks/                          # 9개 후크 (8개 새로 작성)
│   ├── prompt-cache-monitor.sh    # P0 — 캐시 hit rate 모니터링
│   ├── budget-gate.sh             # P0 — USD 누적 cap (hard block)
│   ├── llm-judge.sh               # P1 — Stop hook LLM-as-Judge
│   ├── tool-hash-dedup.sh         # P1 — Tool ping-pong 차단
│   ├── model-router.sh            # P1 — 자동 모델 라우팅
│   ├── tool-selector.sh           # P1 — MCP 카테고리 추천
│   ├── otel-trace-exporter.sh     # P2 — OTel GenAI 형식 변환
│   └── bench-runner.sh            # P2 — Nightly self-bench
│
├── agents/
│   └── judge-agent.md             # P2 — Agent-as-a-Judge
│
├── memory-schema/                  # P2 — Zep temporal memory v2
│   ├── README.md
│   └── examples/
│       └── feedback-2026-05-14-budget-aware-coding.md
│
├── docs/                           # 가이드 문서 (작성 예정)
│   └── (가이드 자료)
│
├── settings/
│   └── settings.example.json      # settings.json 머지 예제
│
└── scripts/
    └── migrate-to-otel.sh          # 기존 JSONL → OTel 일괄 변환
```

---

## 9가지 개선 상세

### P0 — 즉시 적용 권장 (1주)

#### 1. `prompt-cache-monitor.sh` — 캐시 hit rate 모니터링

**WHY**:
- Anthropic 공식: prompt caching으로 **입력 토큰 90% 절감, latency -85ms**.
- 2026 초 TTL 60분 → 5분으로 단축되며 production workload 비용 30~60% 상승 위험.
- CLAUDE.md + rules 합산 ~40K 토큰을 매 턴 재처리하면 월 $300, 캐싱 시 월 $58~99 (-67~80%).

**WHAT**:
- transcript.jsonl을 파싱하여 `cache_read_input_tokens`, `cache_creation_input_tokens` 추적.
- `~/.claude/traces/cache-metrics.jsonl`에 append.
- hit rate < 70% 시 stderr 경고 + `cache-warnings.jsonl` 기록.

**HOW**:
- `Stop` hook으로 세션 단위 집계.
- `settings.json`의 system prompt에 `cache_control: {type: "ephemeral", ttl: "1h"}` 설정 필요 (가이드 참조).

---

#### 2. `budget-gate.sh` — USD 누적 cap

**WHY**:
- **$47K/11일 사고** (Anhaia, 2026.03): 토큰 80% 가드만으로는 누적 ping-pong 못 잡음.
- **$4,200/63h burn** (Sattyam Jain, 2026.02): 429 retry loop.
- 달러 단위 enforcement가 누적/시간차 폭주를 잡는 결정적 게이트.

**WHAT**:
- 모델별 토큰 사용량 × 2026.05 단가 → USD 환산.
- 세션 / 일일 cap 분리 (기본 $5 / $20).
- 80% 도달 시 경고, 100% 초과 시 `decision:block` 출력 (PreToolUse).

**HOW**:
- `PreToolUse` matcher `Bash|Edit|Write` 권장.
- 환경변수로 cap 조정: `CLAUDE_BUDGET_SESSION_USD=5 CLAUDE_BUDGET_DAILY_USD=20`.
- `CLAUDE_BUDGET_MODE=warn`으로 부드럽게 도입 가능.

---

### P1 — 2~3주 (단계적)

#### 3. `llm-judge.sh` — Stop hook LLM-as-Judge

**WHY**:
- Spotify Honk 1,500+ PR 자동화: LLM judge가 **25% 세션 veto**, 절반은 self-correct로 살아남음.
- 결정적 verifier(tsc, ruff, test)만으로는 "agent가 테스트를 살짝 약화시켜 통과시킨" 시나리오 못 잡음.

**WHAT**:
- Stop 시 `git diff HEAD` + recent user prompt → Haiku에 평가 요청.
- 검사 항목: 테스트 약화, 빈 catch, dead code, 보안 이슈, 요청 충실도.
- JSON `{verdict, reason, concerns}` 응답 → BLOCK 시 차단.

**HOW**:
- `ANTHROPIC_API_KEY` 필요합니다.
- 초기 도입은 `CLAUDE_JUDGE_MODE=warn` 권장 (1~2주 관찰 후 block).
- 세션당 1회 호출, Haiku 기준 ~$0.001 / 세션.

---

#### 4. `tool-hash-dedup.sh` — Agent ping-pong 차단

**WHY**:
- $47K 사고 패턴: agent A가 X 만들면 agent B가 되돌리는 ping-pong.
- 파일 편집 횟수만 보는 기존 `loop-detector`는 이 패턴 못 잡음 — **tool-input 자체의 hash 중복**이 본질.

**WHAT**:
- `sha256(tool_name + tool_input)` 계산.
- 동일 세션 5회+ 시 escalate (warn) 또는 block.

**HOW**:
- `PostToolUse` async hook 권장.
- Read/Grep/Glob 같은 탐색 도구는 제외 (반복이 정상).

---

#### 5. `model-router.sh` + `tool-selector.sh` — Dynamic routing

**WHY**:
- Reasoning Sandwich를 수동 매핑만 유지하면 비효율.
- Hybrid routing 37~87% cost reduction (SciForce, vLLM Semantic Router 2026.03).
- MCP 도구 전부 노출 시 context 토큰 낭비 + tool-thrash.

**WHAT**:
- `model-router`: prompt 길이 + 키워드로 Haiku/Sonnet/Opus 추천.
- `tool-selector`: 키워드로 필요한 MCP 카테고리 추천 (github/slack/gmail/jira 등).
- Advisory 출력 — 실제 전환은 사용자 결정.

**HOW**:
- `UserPromptSubmit` hook으로 발동.
- Output: `hookSpecificOutput` JSON으로 컨텍스트 주입.

---

### P2 — 1~2개월 (중기)

#### 6. Memory frontmatter v2 (Zep 패턴)

**WHY**:
- Zep LongMemEval 63.8% vs Mem0 49.0% (**+14.8pt**) — 시간 차원의 압도적 우위.
- 기존 v1 메모리는 append-only, 6개월 후 stale 누적 → 어느 게 진실인지 분간 불가.

**WHAT**:
- frontmatter에 `valid_from` / `valid_until` / `supersedes` / `confidence` / `tags` 추가.
- v1 메모리는 그대로 동작 (점진 마이그레이션).

**HOW**:
- [`memory-schema/README.md`](./memory-schema/README.md) 참조.
- [`memory-schema/examples/`](./memory-schema/examples/) 예제.

---

#### 7. `judge-agent.md` — Agent-as-a-Judge

**WHY**:
- 24개 agent 모두 *생산*에 집중. 출력 품질을 자동 평가하는 judge 부재가 가장 큰 공백.
- Agent-as-a-Judge (arXiv 2508.02994): multi-agent 출력의 일관성 검증.

**WHAT**:
- 5차원 rubric (Faithfulness, Test integrity, Security, Code quality, Reversibility) × 1~5점.
- 최종 verdict: PASS / BLOCK / PASS_WITH_CONCERNS.
- Evidence-based: 모든 claim에 quote 필요합니다.

**HOW**:
- coordinator agent 또는 `/autopilot`이 final merge 전에 호출.
- 출력은 JSON 만 (narrative 금지).

---

#### 8. OpenTelemetry GenAI conventions

**WHY**:
- 2026.03 Datadog가 GenAI semantic conventions native 지원.
- 자체 JSONL 포맷은 Langfuse/LangSmith 연동 시 매핑 비용 발생.
- 미래 마이그레이션 비용을 지금 막아둔다.

**WHAT**:
- `gen_ai.operation.name`, `gen_ai.system`, `gen_ai.tool.name`, `gen_ai.usage.*` attribute.
- 기존 `trace-logger.sh`와 병행 운영 (점진 마이그레이션).

**HOW**:
- `PostToolUse` hook으로 실시간 변환 ([`otel-trace-exporter.sh`](./hooks/otel-trace-exporter.sh)).
- 기존 trace 일괄 변환: [`scripts/migrate-to-otel.sh`](./scripts/migrate-to-otel.sh).

---

#### 9. `bench-runner.sh` — Self-benchmarking

**WHY**:
- LangChain Terminal Bench 52.8% → 66.5% 개선의 핵심은 **매 변경 후 89-task 재실행**.
- 자체 self-eval 루프 없으면 미들웨어 변경 효과를 측정 불가.

**WHAT**:
- Terminal Bench mini 20-task subset 매일 새벽 실행.
- 각 task: `README.md` (요구사항) + `verify.sh` (검증 스크립트).
- 결과를 `~/.claude/traces/bench-results.jsonl`에 append.

**HOW**:
- cron 권장: `0 3 * * * bash ~/.claude/hooks/bench-runner.sh`.
- 초기 task 디렉토리 셋업 필요 ([mini-SWE-agent](https://github.com/SWE-agent/mini-swe-agent) 참조).

---

## 적용 방법 (요약)

상세는 [SETUP_GUIDE_macOS.md](./SETUP_GUIDE_macOS.md) 참조. 빠른 시작:

```bash
# 1. 레포 클론
git clone https://github.com/hyunseung-aicx/claude_skill.git
cd claude_skill

# 2. 후크 실행 권한
chmod +x hooks/*.sh scripts/*.sh

# 3. 환경변수 (~/.zshrc 또는 ~/.bash_profile)
export CLAUDE_SKILL_DIR="$(pwd)"
export ANTHROPIC_API_KEY="sk-ant-..."   # llm-judge.sh 용
export CLAUDE_JUDGE_MODE="warn"          # 초기 도입은 보수적
export CLAUDE_BUDGET_SESSION_USD=5
export CLAUDE_BUDGET_DAILY_USD=20

# 4. settings.json 머지 (settings/settings.example.json 참고)
# 가이드 문서 따라 진행 — 기존 ~/.claude/settings.json과 머지

# 5. cron 등록 (선택)
crontab -e
# 0 3 * * * /bin/bash $CLAUDE_SKILL_DIR/hooks/bench-runner.sh
```

---

## 의존성

| 도구 | 필수도 | 용도 |
|------|--------|------|
| `bash` 5+ | 필수 | 후크 실행 |
| `jq` | 필수 | JSON 파싱 (모든 후크) |
| `curl` | 필수 | `llm-judge.sh` API 호출 |
| `shasum` | 필수 | `tool-hash-dedup.sh` (macOS 기본 제공) |
| `awk` | 필수 | `budget-gate.sh` 부동소수 계산 (macOS 기본 제공) |
| `claude` CLI | bench만 | `bench-runner.sh` (Claude Code 설치 시 자동) |

macOS 설치: `brew install jq` (나머지는 기본 제공).

---

## 참고 자료 (1차 출처)

### 하네스 엔지니어링
- [LangChain — Improving Deep Agents with Harness Engineering (2026.03)](https://www.langchain.com/blog/improving-deep-agents-with-harness-engineering) — Terminal Bench 52.8 → 66.5%
- [LangChain — How Middleware Lets You Customize Your Agent Harness](https://www.langchain.com/blog/how-middleware-lets-you-customize-your-agent-harness)
- [Anthropic — Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Anthropic — Three-Agent Harness Design (2026.03)](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- [Anthropic — Managed Agents (2026.04)](https://www.anthropic.com/engineering/managed-agents)
- [OpenAI — Harness Engineering (2026.02)](https://openai.com/index/harness-engineering/)
- [Phil Schmid — The Importance of Agent Harness in 2026](https://www.philschmid.de/agent-harness-2026)
- [Martin Fowler — Harness Engineering for Coding Agent Users](https://martinfowler.com/articles/harness-engineering.html)

### 자율 에이전트 & 사고 사례
- [Spotify Engineering — Honk Part 3: Verification Loops (2025.12)](https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3) — 25% veto 패턴
- [Anhaia — $47K Autonomous Loop Postmortem (2026.03)](https://dev.to/gabrielanhaia/the-agent-that-spent-47k-on-itself-an-autonomous-loop-postmortem-3313)
- [Sattyam Jain — $4,200 in 63 hours postmortem](https://medium.com/@sattyamjain96/the-agent-that-burned-4-200-in-63-hours-a-production-ai-postmortem-d38fd9586a85)
- [METR — Time Horizon 1.1 (2026.01.29)](https://metr.org/blog/2026-1-29-time-horizon-1-1/) — Opus 4.6: 14.5h
- [Anthropic — Building a C compiler with parallel Claudes](https://www.anthropic.com/engineering/building-c-compiler)
- [Claude Code `/goal` Documentation (2026.05.12)](https://code.claude.com/docs/en/goal)
- [Continuous Claude (Ralph Loop 원조) — AnandChowdhary](https://github.com/AnandChowdhary/continuous-claude)
- [Fortune — AI agents promise to work while you sleep (현실 경고)](https://fortune.com/2026/02/23/always-on-ai-agents-openclaw-claude-promise-work-while-sleeping-reality-problems-oversight-guardrails/)

### 보안 (OWASP & 사례)
- [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)
- [Deep Dive into OWASP Top 10 for Agentic 2026 — NeuralTrust](https://neuraltrust.ai/blog/owasp-top-10-for-agentic-applications-2026)
- [5 AI Agent Security Breaches in 2026 — Beam.ai](https://beam.ai/agentic-insights/ai-agent-security-breaches-2026-lessons) — GTG-1002, Step Finance, ClawHavoc, EchoLeak
- [Portal26 Agentic Token Controls — SiliconANGLE](https://siliconangle.com/2026/04/23/portal26-launches-agentic-token-controls-cap-runaway-ai-agent-spend/)

### 추론 예산 (Reasoning Sandwich)
- [arxiv 2604.14853 — Adaptive Test-Time Compute Allocation](https://arxiv.org/html/2604.14853)
- [arxiv 2605.08083 — AutoTTS](https://arxiv.org/abs/2605.08083)
- [arxiv 2505.11274 — SelfBudgeter](https://arxiv.org/html/2505.11274v6)
- [arxiv 2507.02076 — Reasoning on a Budget Survey](https://arxiv.org/html/2507.02076v1)
- [OpenAI Codex xhigh dual-tier strategy](https://agentmarketcap.ai/blog/2026/04/08/openai-codex-xhigh-vs-standard-dual-tier-agent-strategy)

### 메모리 (Persistent + Temporal)
- [Anthropic Memory Tool Docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool)
- [Anthropic — Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Zep — A Temporal Knowledge Graph Architecture (arXiv 2501.13956)](https://arxiv.org/abs/2501.13956)
- [A-MEM — Agentic Memory for LLM Agents (arXiv 2502.12110)](https://arxiv.org/abs/2502.12110)
- [State of AI Agent Memory 2026 — Mem0](https://mem0.ai/blog/state-of-ai-agent-memory-2026)
- [Letta V1 Agent Architecture](https://www.letta.com/blog/letta-v1-agent)
- [Graphiti — Neo4j blog](https://neo4j.com/blog/developer/graphiti-knowledge-graph-memory/)

### 평가 (Eval)
- [Spotify Honk LLM-as-Judge](https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3)
- [Agent-as-a-Judge — arXiv 2508.02994](https://arxiv.org/html/2508.02994v1)
- [Judge Reliability Harness — arXiv 2603.05399](https://arxiv.org/html/2603.05399v1)

### 벤치마크
- [SWE-bench Verified Leaderboard](https://www.swebench.com/verified.html)
- [SWE-Bench Pro (arXiv 2509.16941)](https://arxiv.org/abs/2509.16941) — contamination 해결
- [Terminal-Bench 2.0 Leaderboard](https://www.tbench.ai/leaderboard/terminal-bench/2.0)
- [mini-SWE-agent — Princeton/Stanford](https://github.com/SWE-agent/mini-swe-agent) — bash-only 74%
- [Berkeley RDI — How We Broke Top Benchmarks](https://rdi.berkeley.edu/blog/trustworthy-benchmarks-cont/)

### Observability
- [OpenTelemetry GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/)
- [OTel GenAI Agent Spans](https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/)
- [Datadog native OTel GenAI support](https://www.datadoghq.com/blog/llm-otel-semantic-convention/)
- [Agent Observability comparison — DigitalApplied](https://www.digitalapplied.com/blog/agent-observability-platforms-langsmith-langfuse-arize-2026)

### Prompt Caching
- [Anthropic Prompt Caching Docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [How Prompt Caching Works in Claude Code — ClaudeCodeCamp](https://www.claudecodecamp.com/p/how-prompt-caching-actually-works-in-claude-code)
- [Claude Code 5-min TTL change cost analysis](https://dev.to/whoffagents/claude-prompt-caching-in-2026-the-5-minute-ttl-change-thats-costing-you-money-4363)
- [LangChain Anthropic Prompt Caching Middleware](https://reference.langchain.com/python/langchain-anthropic/middleware/prompt_caching/AnthropicPromptCachingMiddleware)

### 한글 자료
- [channel.io — 하네스 엔지니어링이란?](https://channel.io/ko/blog/articles/what-is-harness-2611ddf1)
- [AWS Korea Tech — 하네스 엔지니어링으로 본 Deep Insight](https://aws.amazon.com/ko/blogs/tech/harness-engineering-from-deep-insight/)
- [pxd Tech — 하네스 엔지니어링](https://tech.pxd.co.kr/post/하네스-엔지니어링-341)
- [enhans.ai — Harness Engineering 멀티 에이전트 성능](https://www.enhans.ai/newsroom/harness-engineering-how-to-make-multi-ai-agent-actually-work)

---

## 라이선스 & 기여

이 레포는 개인 학습/공유 목적으로 작성되었습니다. 후크/스크립트는 PR/issue 환영.

**Maintainer**: [hyunseung-aicx](https://github.com/hyunseung-aicx)
**Original Setup Source**: [hyunseung1119/My_ClaudeCode_Skill](https://github.com/hyunseung1119/My_ClaudeCode_Skill)

---

## 변경 이력

- **2026-05-14 (v6)**: 9가지 SOTA 패턴 적용 — B+ (82.5) → A (92.6).
- **2026-04 (v5)**: 20-middleware 파이프라인 완성 — B+ (85). [SETUP_SCORE_2026-04.md](https://github.com/hyunseung1119/My_ClaudeCode_Skill/blob/main/SETUP_SCORE_2026-04.md) 참조.
