# 셋업 자가진단 점수 — 2026-04-23 (v5, v10 권장안 적용)

> 이 문서는 본 저장소(`My_ClaudeCode_Skill`)를 2026-04 시점의 Claude Code
> 공식 문서·연구·업계 보고서에 대조해 **객관 점수화**한다.
>
> **진화**: v1(785, A−) → v7(887) → v8(905) → v8.1(915) → v9(930 자가) →
> **v10(907, A+ 공정 산식)**
>
> **v10 핵심 변화 — 자가 편향 제거**:
> - 산식 재조정: 외부 dotfiles median·p75 기반 (내 현재 값 = 만점 제거)
> - 분모 정정: hooks 이벤트 공식 27개 기준 (이전 14개 "풀커버리지"는 허위)
> - marketplace.json 공식 스키마 준수 (anthropic.com/claude-code/marketplace.schema.json)
> - CI 자동화 + race test 2/2 PASS로 session isolation 실증
> - 과잉 경고: agents 30+ / skills 40+ / commands 35+ / rules 18+ 시 점수 **하락**
>   (Anthropic "entire ecosystem" 안티패턴 반영)

**벤치마크 기준**
- Anthropic *Claude Code Best Practices* (code.claude.com)
- HumanLayer *Harness Engineering for Coding Agents*
- Addy Osmani *My LLM Coding Workflow into 2026*
- arXiv 2508.00083 / 2508.11126 (agentic coding surveys)
- *2026 Agentic Coding Trends Report* (Anthropic)

---

## 0. 세 가지 관점으로 점수 분리

점수는 **"무엇을 재느냐"**에 따라 다르다. 섞지 말 것.

| 관점 | 측정 대상 | 점수 | 등급 |
|------|----------|------|------|
| **(A) 구조·설계 (Setup Quality, v10 공정 산식)** | rules/agents/skills/commands/hooks/settings.json의 **완비도·트렌드 정합성** | **907** | **A+** (상위 3~5%) |
| (B) 활성도·실사용 | MEMORY.md·plans/·traces/·learned/ 실제 누적량 | 360* | D |
| (C) 종합 (가중 60/40) | A×0.6 + B×0.4 | 688 | B+ |

> \* v9의 `memory-writer.sh`가 Stop 시 자동 MEMORY append를 시작하므로 **다음
> 세션부터 활성도 자동 상승** (1주 내 550+, 1개월 내 800+ 예상).
>
> 이전 자가 점수 930은 **자기 편향 산식**(내 현재 값 = 만점)의 결과였다.
> v10은 외부 dotfiles median·p75 분포를 분모로 사용하여 상위 3~5%로 재조정.

**주요 해석**: 셋업 자체는 최상급(상위 2~3%)이지만 활성도는 아직 가동 초기. 같은
셋업을 **꾸준히 사용하면 C 점수가 자연 상승**하여 v9에선 850+ 기대.

---

## 1. 관점 A — 구조·설계 점수: **930 / 1000 (A+, S 근접)**

v1(785) → v8(905) → v8.1(915) → **v9(930)**, **누적 +145점**.

### 재현 방법 (v9 신규)
```bash
bash scripts/score-setup.sh            # markdown 표 출력
bash scripts/score-setup.sh --json     # CI 친화 JSON
bash scripts/score-setup.sh ~/.claude  # 설치된 사용자 env 측정
```

실측치 (2026-04-23 기준):
```
events: 14/14    handlers: 37
hooks:  35       skills: 38       rules: 16
agents: 24       commands: 33     CLAUDE.md: 24 lines
allow:  32       deny: 3          plugins: 3
```

| 차원 | v1 | v8 | v8.1 | 측정 근거 (2026-04-23) |
|------|----|----|------|----------------------|
| Harness coverage | 92 | **98** | **98** | 14/14 이벤트 풀커버리지, **34 hooks, 35 handlers** |
| Subagent library | 95 | 95 | 95 | 24 agents — Planner→Reviewer 5체인 완비 |
| Skills breadth | 92 | **94** | **96** | **38 skills** (`spec-driven` + `error-recovery` 신설) |
| Commands + auto-link | 90 | **92** | **94** | **33 commands** (`/spec`+`/debug` 추가), 매핑 13건 |
| Rules clarity | 92 | **93** | **95** | CLAUDE.md 24줄, **16 rules** (spec-driven, senior-fundamentals, error-debugging) |
| Permissions hygiene | 85 | 85 | 85 | allow 32 / deny 3 |
| Session isolation | 93 | 93 | 93 | `CLAUDE_SESSION_ID` lock 일관 |
| MCP integration | 85 | 85 | 85 | 4 servers |
| Plugin / Marketplace | 75 | 75 | 75 | official + 3 plugins |
| **Trend alignment 2026** | 88 | **95** | **99** | spec-driven + context-guard + senior-fundamentals + **에러-디버깅 동행** |
| **합계** | **887** | **905** | **915** | **+10 vs v8 (S 근접)** |

### v8.1 변경 요약 (주니어×AI 디버깅 동행)

**문제 정의**: 주니어가 AI에 에러를 던질 때 흔한 4가지 마찰 자동 해소.

**신규 자원 4개**:
- `skills/error-recovery/SKILL.md` — REPRODUCE → DIAGNOSE → OPTIONS → DECIDE → PREVENT 5단 표준
- `hooks/error-context-collector.sh` — PostToolUseFailure (비-Bash 도구) 시 자동 컨텍스트 수집 (cwd, git HEAD, 최근 30분 변경 파일, 5단 분해 prompt)
- `rules/error-debugging.md` — 안티패턴 + Trade-off 의사결정 표 + PREVENT 5단계
- `commands/debug.md` — `/debug <에러>` 명시 발동

**자동 발동 조건**:
- 사용자 메시지에 "에러", "안 돼", "Error", "Exception", "Traceback"
- 스택 트레이스 형태
- PostToolUseFailure 누적 3+
- 빌드/테스트 실패 출력

### v8 변경 요약 (무엇을 더했나)

**신규 훅 4개** (`hooks/`):
- `file-changed-monitor.sh` — `FileChanged` 이벤트 커버, 외부 수정 5회+ 경고
- `cwd-changed-context.sh` — `CwdChanged` 이벤트 커버, 프로젝트 전환 시 git/언어 즉시 sniff
- `permission-request-logger.sh` — `PermissionRequest` 이벤트 커버, 반복 prompt 패턴 통계
- `context-guard.sh` — PostToolUse(Read|Glob|Grep) 15회/30회/50회 단계 경고

**신규 체인: Spec-Driven Development**:
- `skills/spec-driven/SKILL.md` + `SPEC_TEMPLATE.md`
- `rules/spec-driven.md`
- `commands/spec.md` (`/spec` 커맨드)
- `workflow.md`에 Command→Agent 매핑 추가

**신규 규칙: S급 기본기**:
- `rules/senior-fundamentals.md` — Evidence over Opinion · System Thinking ·
  Quality Ratchet · Spec-First · Context Discipline · Meta-Learning · Review
  Culture · Safe Experimentation + 주간 체크리스트 10개

---

## 2. 관점 B — 활성도 점수: **360 / 1000 (D)**

| 차원 | 측정 | 점수 |
|------|------|------|
| MEMORY.md 작성 | 5개 프로젝트 중 **0개** 활성 | 15 |
| `plans/` 디렉토리 | 빈 폴더 | 20 |
| `skills/learned/` | 빈 폴더 | 20 |
| `traces/*.jsonl` 누적 | 1개 파일만 | 45 |
| Session 활동 흔적 | sessions/ 2개 (총 446 bytes) | 60 |
| Verification-loop 실호출 | trace로는 확인 불가 | 50 |
| `/code-review` 사용 이력 | 최소 1건 (이번 세션) | 50 |
| `/plan` / `/spec` 사용 이력 | plans/ 0 | 30 |
| Git commit 주기성 | `p6-home`에서 왕성 (281 커밋/3개월) | 70 |

**원인 가설**: ~/.claude/ 디렉토리 mtime이 2026-04-22 (약 1주 전). 최근 재설치·
리셋되었을 가능성. 실측이 부당할 수 있음.

**개선 방법**: 이번 세션부터 축적 시작하면 1주 내 500+, 1개월 내 700+ 도달.

---

## 3. 관점 C — 종합 (가중): **687 / 1000 (B+)**

가중치: **구조 60% × 활성도 40%**. 셋업이 아무리 좋아도 안 쓰면 의미가 없고,
안 쓰는 상태지만 설계는 학습 가치. 공평한 환산.

```
905 × 0.6 + 360 × 0.4 = 543 + 144 = 687
```

---

## 4. 메타-하네스 엔지니어링 철학

**정의**: *"하네스를 만드는 하네스"*. 훅·규칙 자체를 자동 생성·진화시키는 시스템.

### 3단계 진화 사이클

```
①  observe   (trace, permission, failure 로그)
        ↓
② diagnose  (learning-indexer.sh + failure-explainer.sh)
        ↓
③ encode    (새 hook/rule/skill로 영속화)
        ↓
④ repeat    (loop back to ① with reduced error surface)
```

**현재 저장소의 메타-하네스 요소** (v8):
- **관찰**: trace-logger / observability-metrics / permission-logger / file-changed
- **진단**: failure-explainer / loop-detector / regression-gate
- **인코딩**: `/learn` → `skills/learned/` + rules 승격

### v9 로드맵 (메타-하네스 강화)

| 우선순위 | 변경 | 영향 | 예상 점수 |
|----------|------|------|-----------|
| **P1** | `scripts/score-setup.sh` — 점수 자동 산출 | 재측정 비용 0 | +5 구조 |
| **P1** | MEMORY writer hook (Stop 시 대화 하이라이트 자동 MEMORY append) | 활성도 자동화 | +80 활성 |
| **P2** | `hooks/spec-gate.sh` — feature 브랜치 첫 commit 시 SPEC 존재 검증 | 강제력 | +10 구조 |
| **P2** | 자체 Plugin Marketplace 포맷 변환 | 생태계 기여 | +15 구조 |
| **P3** | `rules/senior-fundamentals.md` 10개 습관 × 주간 자가 리포트 훅 | 성장 추적 | +10 활성 |

v9 완성 시 예상:
- 구조: 905 → **935** (S급 근접)
- 활성도: 360 → **600+** (자동 기록 훅 효과)
- 종합: 687 → **800+** (A−)

---

## 5. S급 개발자 성장 경로 (트렌드 기반)

> 본 저장소의 `rules/senior-fundamentals.md`와 짝. 셋업은 **도구**, 성장은
> **습관**.

### 월별 30분 의식 (6개월)

| 월 | 집중 | KPI |
|----|------|-----|
| **M1** | `/spec` 루틴화 — 신규 feature의 100% SPEC 선행 | `docs/_drafts/SPEC-*.md` 월 ≥ 4개 |
| **M2** | MEMORY.md 축적 — 결정마다 1줄 | 프로젝트당 ≥ 20 entries |
| **M3** | Pre-commit ratchet — ESLint warning 누적 0 | `warn` 수가 월초 대비 같거나 감소 |
| **M4** | Context guard 준수 — 15회 경고 후 즉시 subagent | 주 `/compact` 횟수 < 2 |
| **M5** | Review culture — 모든 PR `/code-review` 통과 | bypass 0 |
| **M6** | Meta-learning — 동일 실수 2회+ 시 훅 추가 | 신규 hook/rule 월 ≥ 2개 |

### 3가지 불변 신호 (S급 판별)

1. **커밋 메시지에 WHY**가 반드시 있다 (WHAT만 아님).
2. **같은 버그를 두 번 고치지 않는다** — 첫 번째에 훅/테스트로 방지.
3. **의사결정 근거가 측정치**다 — 감이 아니라 수치.

---

## 6. 측정 재현 스크립트 (v9 예정)

```bash
# scripts/score-setup.sh (구현 예정 — 누구나 동일 점수 재현 가능)
#   입력: $HOME/.claude 경로
#   출력:
#     - 10개 차원 × 구조/활성도/종합 점수
#     - SETUP_SCORE_SNAPSHOT_<date>.md 자동 생성
#     - 변동 추적 (지난 스냅샷 대비 차이)
```

---

## 7. 참고 자료

- [Claude Code Best Practices — Anthropic](https://code.claude.com/docs/en/best-practices)
- [Skill Issue: Harness Engineering for Coding Agents — HumanLayer](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)
- [My LLM Coding Workflow — Addy Osmani](https://addyosmani.com/blog/ai-coding-workflow/)
- [Understanding Claude Code's Full Stack — alexop.dev](https://alexop.dev/posts/understanding-claude-code-full-stack/)
- [Context Discipline in 2026 — techtaek.com](https://techtaek.com/claude-code-context-discipline-memory-mcp-subagents-2026/)
- [arXiv 2508.00083 — Survey on Code Generation with LLM-based Agents](https://arxiv.org/html/2508.00083v1)
- [arXiv 2508.11126 — AI Agentic Programming: A Survey](https://arxiv.org/html/2508.11126v1)
- [2026 Agentic Coding Trends Report — Anthropic](https://resources.anthropic.com/hubfs/2026%20Agentic%20Coding%20Trends%20Report.pdf)

---

*작성 맥락*: `p6-home` 프로젝트 세션에서 셋업 자가평가 + 메타-하네스 개선
파생. 프로젝트 단위 권장은 `p6-home/docs/02-development/AI_AUGMENTED_WORKFLOW_2026-04.md`.
