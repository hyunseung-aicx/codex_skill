# 🤖 agents/ — 에이전트 (전문가 인격 분리)

> **한 줄 요약**: 클로드 코드가 부르는 전문가들입니다. 변호사·회계사·정비공처럼 각자 자기 영역만 깊이 다룹니다.

---

## 에이전트가 뭔가요?

**에이전트(agent)** 는 클로드 코드의 메인 세션과 **별도로 실행되는 클로드 인격**입니다. 각자 자기 전문 영역의 지식과 도구만 가지고 일합니다.

### 회사 비유

| 회사 역할 | 클로드 에이전트 |
|----------|--------------|
| CEO / 매니저 | 메인 세션 (사용자와 대화하는 클로드) |
| 변호사 (법률) | `security-reviewer` (보안 검토) |
| 회계사 (재무) | `performance-optimizer` (성능 분석) |
| 정비공 (수리) | `debugger` (런타임 에러 디버깅) |
| 건축가 (설계) | `architect` (시스템 설계) |
| 외부 감사 | `judge-agent` (최종 판정) — **이번에 새로 추가** |

매니저가 모든 분야를 직접 다루면 깊이가 얕고 헷갈립니다. 전문가에게 위임하면 더 정확한 답이 나옵니다.

### 왜 분리하나요?

1. **컨텍스트 분리** — 메인 세션이 너무 많은 정보를 기억하면 헷갈립니다. 에이전트는 자기 일만 보고 결과만 보고.
2. **전문성** — 보안 에이전트는 OWASP Top 10을 항상 머릿속에 두고, Python 리뷰어는 type hint 규칙을 항상 적용.
3. **병렬 처리** — 보안·성능·접근성을 동시에 검토 가능.

---

## 이 폴더에 있는 에이전트

이 레포에는 **`judge-agent.md`** 1개만 있습니다. 기존 24개 에이전트는 [기존 셋업](https://github.com/hyunseung1119/My_ClaudeCode_Skill)에 이미 정의되어 있고, 이 레포는 **그 위에 1개를 추가**합니다 (24 → 25).

### `judge-agent.md` — 최종 판정관

**비유**: 회사의 최고 감사. 다른 사람 의견(코드 리뷰어, 보안 검토자, 테스트)을 종합해 **PASS / BLOCK / 조건부 PASS** 판정.

**왜 추가했나요?**:
- 기존 24개 에이전트는 모두 "**일하는**" 에이전트입니다 (생성·검토·구현).
- 그런데 **그 결과를 종합 판정**하는 에이전트가 없었습니다.
- 예: 코드 리뷰어가 "OK", 보안 검토자가 "OK"라고 했어도 → **정말 사용자가 원한 걸 만들었는가?** 는 별개 질문.

**작동 방식**:

5가지 기준으로 1~5점씩 채점합니다.

| 기준 | 무엇을 보는가 |
|------|--------------|
| **충실도 (Faithfulness)** | 사용자가 요청한 걸 정말 만들었는가, 옆길로 샜는가 |
| **테스트 무결성 (Test integrity)** | 통과시키려고 테스트를 약화시키지 않았는가 |
| **보안 (Security)** | 하드코딩 비밀번호, SQL 인젝션, 인증 누락 등 |
| **코드 품질 (Code quality)** | 함수 크기, 중복, 디버그 로그 잔존 등 |
| **가역성 (Reversibility)** | 잘못됐을 때 안전하게 롤백 가능한가 |

총점 기준:
- 19점 이상 → PASS ✅
- 12점 이하 → BLOCK ❌
- 13~18 → 조건부 PASS ⚠️

**학술 근거**:
- Spotify Engineering (2025.12): LLM judge가 **1,500+ PR 자동화 세션의 25%를 veto**.
- Agent-as-a-Judge (arXiv 2508.02994, 2025.08): multi-agent 출력의 일관성을 단일 critique loop보다 정확하게 검증.
- Judge Reliability Harness (arXiv 2603.05399, 2026.03): structured judge가 narrative critique보다 actionable.

---

## 예제 — 어떻게 호출되나요?

### 시나리오: 로그인 기능 추가

```
사용자: "로그인 기능 만들어줘"
     ↓
[메인 클로드 — Opus]
  ├─ planner 에이전트 호출 → 단계별 계획 수립
  ├─ 코드 작성 (Sonnet)
  ├─ code-reviewer 에이전트 호출 → "함수 너무 큼" (3/5)
  ├─ security-reviewer 에이전트 호출 → "평문 비밀번호!" (2/5)
  ├─ tdd-guide 에이전트 호출 → "테스트 없음" (1/5)
  └─ judge-agent 호출
        ↓
[judge-agent 평가]
  rubric:
    faithfulness: 4 (로그인은 만듦)
    test_integrity: 1 (테스트 자체가 없음)
    security: 2 (평문 비밀번호)
    code_quality: 3 (함수 분리 필요)
    reversibility: 4 (롤백 가능)
  total: 14
  verdict: PASS_WITH_CONCERNS

  block_reasons: []
  concerns:
    - "테스트 누락 — 추가 필요"
    - "비밀번호 해싱 필수"

[메인 클로드]
  → 테스트 작성 + bcrypt 적용 → 재호출
     ↓
[judge-agent 재평가]
  total: 22 → PASS ✅
```

이렇게 **자동 재시도 루프**가 형성됩니다. 결정적 verifier(test/tsc/ruff)만으론 이런 패턴이 안 됩니다.

---

## 어떻게 활성화하나요?

`agents/judge-agent.md` 파일이 `~/.claude/agents/` 또는 `${CLAUDE_SKILL_DIR}/agents/` 에 있으면 클로드 코드가 자동 인식합니다.

심볼릭 링크 권장:
```bash
ln -s $CLAUDE_SKILL_DIR/agents/judge-agent.md ~/.claude/agents/judge-agent.md
```

수동 호출:
```
@judge-agent 현재 변경사항을 평가해주세요.
```

자동 호출 (권장):
- `coordinator` 에이전트가 multi-agent 작업 종료 시 자동 호출
- `/autopilot` 무인 운영 시 PR 머지 직전 자동 호출

---

## 기존 24개 에이전트 — 참고

| 카테고리 | 에이전트 (24개) |
|---------|--------------|
| **Core (7)** | planner, code-reviewer, tdd-guide, security-reviewer, build-error-resolver, debugger, architect |
| **Quality (10)** | a11y-reviewer, database-reviewer, python-reviewer, go-reviewer, go-build-resolver, graphql-expert, rust-expert, refactor-cleaner, performance-optimizer, doc-updater |
| **Domain (4)** | react-agent, e2e-runner, infrastructure-agent, vector-db-agent |
| **Meta (3)** | coordinator, critic-agent, tree-of-thoughts |
| **🆕 추가 (1)** | **judge-agent** ← 이 레포 |

---

## 더 깊이

- [`./judge-agent.md`](./judge-agent.md) — judge-agent 본체 (영문, 시스템 프롬프트)
- [`../BEGINNERS_GUIDE.md`](../BEGINNERS_GUIDE.md) — 큰 그림
- [`../README.md`](../README.md) — 9가지 개선 항목 중 judge-agent 부분
- [Spotify Honk 사례](https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3)
- [Agent-as-a-Judge 논문](https://arxiv.org/html/2508.02994v1)
