# 모델 라우팅 평가 — Haiku / Sonnet / Opus 최적 배분

> 작성일: 2026-05-14
> 목적: 현재 셋업의 모델 라우팅 규칙이 **학술/산업 SOTA 대비 충분히 정확하고 효율적인지** 평가하고, 부족한 부분을 보강합니다.

---

## 결론 (TL;DR)

| 항목 | 현재 v1 (`model-router.sh`) | 평가 |
|------|--------------------------|------|
| 규칙 유형 | 키워드 + 길이 기반 정적 규칙 | ⚠️ **학술 근거 약함** — 휴리스틱 |
| 단계 분해 | 단일 라우팅 | ❌ AgentTTS 부재 (multi-stage 배분 안 됨) |
| 토큰 예산 예측 | 없음 | ❌ SelfBudgeter 부재 |
| 적응적 재조정 | 없음 | ❌ Adaptive TTC 부재 |
| Sandwich 정합 | Planning=Opus / Impl=Sonnet / Simple=Haiku | ✅ Anthropic Three-Agent와 정합 |
| 자기 측정 | 없음 | ❌ 라우팅 정확도 사후 검증 부재 |

**종합**: v1은 "**없는 것보단 낫다**" 수준입니다. **v2가 필요합니다**. 아래에서 부족한 5가지를 정확히 짚어 보강합니다.

---

## 1. SOTA 연구 정리 (2026년 1~5월)

### 1-1. Anthropic Three-Agent Harness (2026.03)

**출처**: [Anthropic — Harness Design for Long-Running App Development](https://www.anthropic.com/engineering/harness-design-long-running-apps)

| 역할 | 모델 | 추론 수준 | 근거 |
|------|------|----------|------|
| Planner | Opus 4.7 | high | 사양 작성, ambitious scope |
| Generator | Sonnet 4.6 | high | 실제 구현 |
| Evaluator | Haiku 4.5 | low/medium | Playwright MCP로 결과 검증 |

**핵심 수치**: solo Claude 20분 / $9 → full harness 6시간 / $200. 비용 22배지만 **production-grade**.

### 1-2. Terminal Bench 2.0 실측 (LangChain, 2026.03)

**출처**: [LangChain — Improving Deep Agents with Harness Engineering](https://www.langchain.com/blog/improving-deep-agents-with-harness-engineering)

| 추론 수준 | Terminal Bench 2.0 점수 |
|----------|----------------------|
| high (균일) | **63.6%** |
| xhigh (균일) | 53.9% (타임아웃 빈발) |
| Sandwich (xhigh-high-xhigh, Plan-Impl-Verify) | **66.5%** |

**시사점**:
- **xhigh를 모든 단계에서 쓰면 손해** (50k+ 토큰으로 타임아웃)
- Sandwich 패턴 (Plan과 Verify만 xhigh) 이 최적
- 사용자의 "xhigh 금지" 규칙은 **half-right** — 완전 금지보단 **Plan/Verify만 xhigh** 가 SOTA

### 1-3. SelfBudgeter (arXiv 2505.11274)

**핵심**: 모델 자체에게 **"이 답변에 토큰 몇 개 필요한가?"** 먼저 묻고, 그만큼만 할당.

**효과**:
- MATH 데이터셋에서 **matched budget 대비 +12.8% 상대 정확도**
- 과잉 추론(overthinking) 방지

### 1-4. AgentTTS (arXiv 2508.00890)

**핵심**: 작업을 subtask로 분해하고, 각 subtask에 **다른 모델·다른 예산** 배분.

**예**:
- 전체 task: "Auth API 만들고 테스트 작성"
- subtask 1: 스키마 설계 → Opus + 5000 tokens
- subtask 2: 코드 작성 → Sonnet + 15000 tokens
- subtask 3: 테스트 작성 → Sonnet + 8000 tokens
- subtask 4: 코드 리뷰 → Haiku + 3000 tokens

### 1-5. Adaptive Test-Time Compute (arXiv 2604.14853)

**핵심**: Lagrangian relaxation으로 **per-instance 예산 자동 결정**. Static rule보다 runtime adaptive가 효율적.

### 1-6. OpenAI Codex xhigh dual-tier (2026.04)

**출처**: [agentmarketcap.ai](https://agentmarketcap.ai/blog/2026/04/08/openai-codex-xhigh-vs-standard-dual-tier-agent-strategy)

**핵심 패턴**:
- Orchestrator: `high`
- Specialist (복잡한 sub-problem): `xhigh`
- Utility subagent (단순 작업): `medium`
- 효과: 3-5x 비용 절감, 품질 보존

### 1-7. Reasoning on a Budget Survey (arXiv 2507.02076)

**핵심**: 추론 예산을 **균일하게 쓰는 것이 가장 비효율**. 작업별 차등 배분이 표준.

---

## 2. 현재 셋업 평가

### 2-1. `model-router.sh` v1 라우팅 규칙

```bash
# 현재 규칙 (요약)
if prompt < 200 chars + 단순 키워드 (typo, rename, format) → Haiku
elif 설계/리팩토링 키워드 (architecture, refactor, migration) → Opus
elif 보안 키워드 (security, auth) → Opus
elif prompt > 2000 chars → Opus
else → Sonnet
```

### 2-2. 5가지 한계점

#### 한계 1: 200/2000 문자 임계값에 학술 근거 부재
- 현재 임계값은 **직관적 추측**이지 측정 기반이 아닙니다.
- SelfBudgeter 패턴이 정답에 가깝습니다 — **prompt 자체의 복잡도**를 모델이 판단.

#### 한계 2: Token 예산 cap이 모델별로 분리되어 있지 않음
- 현재는 `budget-gate.sh`에서 단일 USD cap만 검사.
- SOTA: **모델별 토큰 예상치** + **subtask별 예산** 분리 (AgentTTS 패턴).

#### 한계 3: Subtask 분해 추천 없음
- 긴 prompt → Opus 단일 호출로 끝.
- SOTA: 긴 prompt → **"이 작업을 3개 subtask로 분해하고, 각각 다른 모델 사용 권장"** 출력.

#### 한계 4: xhigh 활용 부재
- 현재 셋업은 "xhigh 금지"로 단순화.
- SOTA: **Plan/Verify는 xhigh 권장**, Implementation만 high.

#### 한계 5: 라우팅 정확도 사후 검증 없음
- 현재: 추천한 후 끝.
- SOTA: **실제 사용된 모델 vs 추천 모델 비교** → 라우팅 정확도 측정 → 임계값 자동 튜닝.

---

## 3. v2 보강 — `model-router-v2.sh` 설계

### 3-1. 변경 사항 7가지

| # | 변경 | 근거 |
|---|------|------|
| 1 | **Complexity score** 도입 (0~10) — 키워드 + 길이 + 파일 수 + 종속성 가중치 합산 | 단순 키워드 → 다차원 점수 |
| 2 | **3-tier 라우팅** + 추론 수준 분리: `(model, reasoning_level)` 페어 출력 | Anthropic Three-Agent + xhigh dual-tier |
| 3 | **Subtask 분해 추천**: complexity score ≥ 7 시 "3+ subtask로 분해 권장" 메시지 출력 | AgentTTS |
| 4 | **Token budget 추정**: 추천 모델별 예상 input/output 토큰 출력 | SelfBudgeter 변형 (heuristic fallback) |
| 5 | **xhigh 권장 조건** 명시: planning/verification subtask만 xhigh | Terminal Bench 2.0 Sandwich |
| 6 | **Routing accuracy log**: 실제 호출된 모델을 PostToolUse에서 추적, 추천 vs 실제 비교 | LangChain self-eval 패턴 |
| 7 | **Adaptive threshold**: 7일치 사용 데이터로 임계값 자동 튜닝 (옵션) | Adaptive TTC |

### 3-2. Complexity Score 공식

```
score = w_length × log(prompt_len / 100)
      + w_kw_simple × (단순 키워드 매칭 수) × -1
      + w_kw_complex × (복잡 키워드 매칭 수) × +2
      + w_files × (언급된 파일 수)
      + w_modal × (multi-modal: 이미지/문서 첨부 시 +2)

cutoff:
  score < 2  → Haiku, low reasoning
  2 ≤ score < 5 → Sonnet, high reasoning  
  5 ≤ score < 7 → Opus, high reasoning
  score ≥ 7  → Opus, xhigh (planning) + subtask 분해 추천
```

가중치는 초기값을 학술 자료(LangChain, Anthropic) 기반으로 설정하고, `routing-accuracy.jsonl`로 사후 튜닝.

### 3-3. 출력 포맷 (v1 → v2)

**v1** (advisory text):
```
🤖 Model router 추천: opus (이유: design_or_refactor)
```

**v2** (structured advisory + token estimate + subtask suggestion):
```json
{
  "recommended": {
    "model": "opus",
    "reasoning_level": "xhigh",
    "estimated_input_tokens": 8500,
    "estimated_output_tokens": 4200,
    "estimated_cost_usd": 0.45
  },
  "complexity_score": 7.3,
  "reasoning": "Long prompt + 2 complex keywords (refactor, migration) + 5 files mentioned",
  "subtask_split_recommended": true,
  "subtask_plan": [
    {"phase": "plan", "model": "opus", "reasoning": "xhigh", "est_tokens": 2000},
    {"phase": "implement", "model": "sonnet", "reasoning": "high", "est_tokens": 8000},
    {"phase": "verify", "model": "sonnet", "reasoning": "high", "est_tokens": 3000}
  ],
  "alternatives": [
    {"model": "sonnet", "reasoning": "high", "cost_delta_pct": -78}
  ]
}
```

### 3-4. 신규 후크 1개 추가

| 후크 | 이벤트 | 역할 |
|------|--------|------|
| `routing-accuracy-tracker.sh` | PostToolUse (async) | 실제 호출된 모델을 transcript에서 추출 → v2 추천과 비교 → JSONL 기록 |

### 3-5. 사용자에게 제공하는 정보

```
[v1] "Opus 추천"  ← 끝
[v2] "Opus 추천, 예상 비용 $0.45, 또는 3-subtask로 분해 시 $0.10 가능"
        ↑          ↑                ↑
       (모델)      (비용 추정)        (대안)
```

---

## 4. v2 적용 후 기대 효과 (추정)

| 메트릭 | v1 | v2 | 근거 |
|--------|----|----|------|
| 라우팅 정확도 | ~60% (직관 기반) | **~85%** | Complexity score 다차원화 |
| 평균 토큰 사용량 | base | **-25~40%** | Subtask 분해 권장 + alternatives 제시 |
| Plan/Verify 품질 | base | **+5~10pt** (Terminal Bench 환산) | xhigh 권장 패턴 |
| 비용 절감 | base | **-30~50%** | SelfBudgeter 토큰 cap + AgentTTS 분해 |
| 사용자 결정 지원 | "추천 1개" | "추천 + 대안 + 분해" | LangChain self-eval 패턴 |

**구체적 시나리오**:
- v1: 모든 작업을 Sonnet 또는 Opus로 통일 (단순 작업도 비싸게)
- v2: "이 작업은 Haiku로 충분 + 검증만 Sonnet"으로 분해 권장 → 80% 비용 절감

---

## 5. 적용 우선순위 (현 셋업 진단)

| 갭 | 우선순위 | 보강 항목 |
|----|---------|---------|
| Complexity score 도입 | P0 | `model-router-v2.sh` |
| Token budget 추정 | P0 | `model-router-v2.sh` 내장 |
| Subtask 분해 추천 | P1 | `model-router-v2.sh` 내장 |
| xhigh dual-tier 권장 | P1 | `model-router-v2.sh` 내장 |
| Routing accuracy tracking | P2 | `routing-accuracy-tracker.sh` |
| Adaptive threshold | P3 | v3 후속 (실측 데이터 7일+ 축적 후) |

**1단계**: v2 작성 → settings.json에 v1 대신 등록.
**2단계**: `routing-accuracy-tracker.sh` 추가 → PostToolUse에 등록.
**3단계** (선택, 1주 후): 누적 데이터로 임계값 튜닝.

---

## 6. 참고 자료 (1차 출처)

### 모델 라우팅 / Test-Time Compute
- [Adaptive Test-Time Compute Allocation (arXiv 2604.14853)](https://arxiv.org/html/2604.14853)
- [AutoTTS — LLMs Improving LLMs (arXiv 2605.08083)](https://arxiv.org/abs/2605.08083)
- [SelfBudgeter (arXiv 2505.11274)](https://arxiv.org/html/2505.11274v6)
- [AgentTTS — multi-stage task (arXiv 2508.00890)](https://arxiv.org/html/2508.00890)
- [Reasoning on a Budget Survey (arXiv 2507.02076)](https://arxiv.org/html/2507.02076v1)
- [Learning When to Plan (arXiv 2509.03581)](https://arxiv.org/html/2509.03581v1)

### 산업 사례
- [Anthropic — Harness Design (Three-Agent)](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- [LangChain — Improving Deep Agents](https://www.langchain.com/blog/improving-deep-agents-with-harness-engineering)
- [LangChain Middleware — wrap_model_call](https://www.langchain.com/blog/how-middleware-lets-you-customize-your-agent-harness)
- [OpenAI Codex xhigh dual-tier strategy](https://agentmarketcap.ai/blog/2026/04/08/openai-codex-xhigh-vs-standard-dual-tier-agent-strategy)
- [Claude Opus 4.7 — apiyi guide](https://help.apiyi.com/en/claude-opus-4-7-release-features-api-guide-en.html)

### 비용 / Pricing
- [Anthropic Pricing (2026.05 기준)](https://www.anthropic.com/pricing)
- [vLLM Semantic Router — Red Hat](https://www.redhat.com/en/blog/bringing-intelligent-efficient-routing-open-source-ai-vllm-semantic-router)
- [Top AI Gateways 2026 — Dynamic Routing](https://dev.to/kuldeep_paul/top-ai-gateways-with-semantic-caching-and-dynamic-routing-2026-guide-4a0g)
