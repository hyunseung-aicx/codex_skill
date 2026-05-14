# Senior Engineer Fundamentals — S급 기본기

globs: ['**/*']

> 기술 스택보다 **습관**이 시니어를 만든다. 이 문서는 AI 협업 시대(2026+)에
> S급 개발자가 기본 장착해야 할 8가지 행동 규범이다. 규칙이 아닌 **자동 반사**
> 가 될 때까지 반복한다.

## 1. Evidence over Opinion (근거 우선)

- 결정에 **측정치·공식 문서·팀 컨벤션** 중 하나 첨부.
- 없으면 `"근거 없음 — 측정 필요"` 명시.
- 금지: *"~것 같다"*, *"~면 좋을 것 같다"*.
- 벤치마크·로그·로드타임 수치는 커밋 메시지에 포함.

## 2. System Thinking (경계 넘기)

- 프론트만 / 백만 / 인프라만 아는 습관 거부.
- 기능 추가 전 질문: *"DB·API·UI·운영·관측 5축에 영향은?"*
- 예: React 컴포넌트 최적화 ↔ nginx Cache-Control ↔ Prometheus 메트릭 동시에.

## 3. Quality Ratchet (부채 불가역)

- 레포의 품질 지표(ESLint error, coverage, complexity, LOC)가 **내려가는 방향**
  으로는 절대 커밋하지 않는다 (ratchet).
- pre-commit/pre-push 훅을 **자기 방어선**으로 세팅.
- 기존 부채는 천천히 상환, 신규 부채 유입은 훅으로 **원천 차단**.

## 4. Spec-First (waterfall in 15 minutes)

- 비trivial 변경은 SPEC 먼저 (`/spec` 커맨드 자동 발동).
- 5필드 완성 전 Edit/Write 금지.
- 15분 SPEC이 15시간 디버깅을 아낀다.

## 5. Context Discipline (컨텍스트 자원 관리)

- 메인 창은 **의사결정**용. 탐색·조사는 subagent에 위임.
- Read/Glob/Grep 15회 누적 시 `context-guard.sh` 경고 → Explore subagent로.
- CLAUDE.md ≤ 60줄 유지. 긴 규칙은 `rules/*.md`로 offload.

## 6. Meta-Learning (실수 → 훅/규칙)

- 같은 실수를 두 번 하지 않기 위한 **메타 레이어**:
  1. 첫 실수: 바로 수정
  2. 두 번째: `rules/*.md`에 규칙 추가 또는 `hooks/*.sh`로 차단
  3. 세 번째: skill로 승격
- HumanLayer 원칙: *"anytime the agent makes a mistake, engineer a solution so
  it never makes that mistake again."*

## 7. Review Culture (외부 눈)

- 자기 코드 리뷰는 편향. **`/code-review` 항상** → code-reviewer agent 분리 시각.
- security/테스트/성능이 얽힌 변경은 **병렬 리뷰** (3개 agent 동시).
- 리뷰 피드백은 즉시 반영하거나 명시적 유예(TODO + ticket).

## 8. Safe Experimentation (되돌릴 수 있는 용기)

- 위험한 시도는 `git worktree` 또는 feature flag로 격리.
- 되돌릴 수 없는 결정(DB drop, force push to main, rm -rf)은 **반드시 사용자
  확인**. 훅(`dangerous-command-blocker.sh`)에서 이미 차단.
- 실패는 비용이 아니라 **학습 데이터** — 실패를 훅으로 변환(원칙 6).

## 9. Communication Rigor (덤)

- 커밋 메시지: `<type>(<scope>): <what> — <why>`. 무엇만 말하면 중급, 왜까지
  쓰면 시니어.
- PR 설명에 **Test Plan** + **Rollback Plan** 필수.
- 에러 로그는 `🔍 WHAT / WHERE / WHY / FIX / PREVENT` 5단 분해 (`cs-boost.md`).

## 10. Teaching as Reinforcement (덤)

- 새 패턴은 `/learn`으로 기록 → `skills/learned/` 누적.
- MEMORY.md에 결정 사유 남기면 6개월 후의 나에게 선물.
- 팀원에게 설명 가능한 수준이 되면 **진짜 이해한 것**.

---

## 10가지 체크리스트 (매주 1회)

- [ ] 커밋 메시지가 `type(scope): what — why` 패턴?
- [ ] 신규 부채(ESLint warn, LOC, complexity) 하나도 늘지 않았는가?
- [ ] 이번 주 SPEC 작성 수 ≥ 비trivial 변경 수?
- [ ] 같은 실수 두 번 한 적 있으면 훅/규칙화 했는가?
- [ ] `/code-review` 없이 merge한 PR 있었는가? (있으면 원인 분석)
- [ ] 컨텍스트 `/compact` 또는 subagent 위임을 적절히 사용했는가?
- [ ] worktree 또는 feature flag 없이 위험 변경을 main에 직접 했는가?
- [ ] 에러가 날 때 5단 분해 후 fix했는가?
- [ ] MEMORY.md에 이번 주 결정 사유 1개 이상 추가?
- [ ] 주 1회 이상 `/learn` 실행으로 패턴 승격?

---

## 참고

- HumanLayer — *Harness Engineering for Coding Agents*
- Addy Osmani — *My LLM Coding Workflow Going into 2026*
- Anthropic — *2026 Agentic Coding Trends Report*
- 내부 참조: `rules/workflow.md`, `rules/spec-driven.md`, `rules/cs-boost.md`,
  `rules/harness-engineering.md`
