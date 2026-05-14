# 🧠 memory-schema/ — 시간 차원이 있는 사실 기록부

> **한 줄 요약**: 클로드가 기억하는 사실에 "언제부터 / 언제까지 유효한가"를 적어두는 양식입니다.

---

## 왜 필요한가요? (입문자용)

### 자동차 정비 기록부 비유

자동차에 "2024년 브레이크 교체" 기록만 있으면 **5년 뒤에는 의미가 없습니다**. 진짜 정비 기록은:

- 작업: 브레이크 패드 교체
- **언제부터 유효**: 2024-03-15
- **언제까지 유효**: 약 2027-03-15 (3년 후 재교체)
- **확신도**: 95% (정비소 영수증 있음)

이래야 5년 후 정비공이 "어, 이거 교체했지만 이제 새로 해야 할 시기네" 라고 판단할 수 있습니다.

### 클로드의 기존 메모리 문제

기존 메모리는 **추가만 가능**(append-only)했습니다. 그러다 보니:

```
2024-01: "이 프로젝트는 Python 3.9 사용"
2026-05: "이 프로젝트는 Python 3.13 사용"
```

두 기록이 공존하고, 클로드가 **어느 게 진실인지 분간 못합니다**. 6개월 지나면 stale 메모리가 누적되어 헷갈리는 답을 내놓습니다.

### 해결책: Zep 패턴 (Temporal Memory)

Zep은 **시간 차원**을 메모리에 추가한 시스템입니다. 학술 측정(LongMemEval)에서 기존 방식 대비 **+14.8점** 개선을 보였습니다.

핵심 아이디어 4가지:

| 필드 | 의미 |
|------|------|
| `valid_from` | "이 사실은 언제부터 유효한가" |
| `valid_until` | "언제까지 유효한가" (`null` = 현재 유효) |
| `supersedes` | "이전 어떤 기록을 덮어쓰는가" |
| `confidence` | "얼마나 확신하는가" (0~1) |

---

## 예제 — 직접 보면 이해가 빠릅니다

### 예제 1: Python 버전 정보 (시간이 흘러 무효화됨)

**옛 메모리** (`project-python-3-9-version.md`, 2024-01-10 작성):
```yaml
---
name: project-python-3-9-version
description: 이 프로젝트는 Python 3.9 사용
metadata:
  type: project
  valid_from: "2024-01-10"
  valid_until: "2026-05-14"     # ← 이 시점에 무효화됨
  confidence: 0.95
---
```

**새 메모리** (`project-python-3-13-version.md`, 2026-05-14 작성):
```yaml
---
name: project-python-3-13-version
description: 이 프로젝트는 Python 3.13 사용
metadata:
  type: project
  valid_from: "2026-05-14"
  valid_until: null              # 현재 유효
  supersedes:
    - project-python-3-9-version  # ← 옛 메모리를 덮어씀
  confidence: 0.95
---
```

클로드가 "Python 버전이 뭐였더라?" 라고 묻는다면:
- 옛 메모리 → `supersedes` 됐으니 무시
- 새 메모리 → "3.13" 답변, 확신도 95%

### 예제 2: 사용자 선호도 (현재 유효한 사실)

```yaml
---
name: user-prefers-pytest-over-unittest
description: 사용자는 pytest를 unittest보다 선호 (간결성·fixture 활용)
metadata:
  type: user
  valid_from: "2026-05-14"
  valid_until: null
  confidence: 0.90
  tags: ["python", "testing", "preference"]
---

사용자가 명시적으로 "unittest 말고 pytest로 작성해줘"라고 요청.
이후 모든 Python 테스트 작성 시 pytest 기본 채택.
```

### 예제 3: 시한부 결정 (자동 만료)

```yaml
---
name: feature-flag-new-checkout-enabled
description: 새 결제 페이지 feature flag 활성화
metadata:
  type: project
  valid_from: "2026-05-14"
  valid_until: "2026-06-01"   # ← 2주 후 자동 만료 (실험 기간)
  confidence: 1.0
  tags: ["feature-flag", "checkout"]
---

A/B 테스트 결과 따라 2주 후 결정.
- 성공: 영구 활성화 → 새 메모리 작성
- 실패: feature flag 제거 → 이 메모리 그대로 만료
```

`valid_until` 이 지나면 클로드가 자동으로 "이 메모리는 stale" 표시하고 advisory로만 사용합니다.

---

## Frontmatter 전체 스펙

```yaml
---
name: budget-aware-coding             # 고유 슬러그 (kebab-case)
description: 한 줄 요약                # 검색·필터용 짧은 설명
metadata:
  type: feedback                       # user / feedback / project / reference

  # 🆕 v2 추가 필드
  valid_from: "2026-05-14"             # ISO-8601 날짜
  valid_until: null                    # null = 현재 유효
  supersedes: []                       # 무효화하는 다른 메모리 slug 배열
  confidence: 0.95                     # 0.0~1.0
  source: "Anhaia $47K postmortem"    # 출처 (선택)
  tags: ["autonomous", "budget", "p0"] # 검색/필터용 (선택)
---

[메모리 본문 — markdown 자유 작성]
```

---

## 4가지 type — 무엇을 어디에?

기존 클로드 메모리 시스템의 4분류를 그대로 유지합니다.

| Type | 용도 | 예시 |
|------|------|------|
| `user` | 사용자 개인 정보·역할·취향 | "사용자는 시니어 백엔드 개발자, 도커 선호" |
| `feedback` | "이런 작업할 땐 이렇게" 같은 행동 가이드 | "정수 비교는 항상 `===`, 절대 `==` 사용 금지" |
| `project` | 특정 프로젝트의 사실·결정 | "이 프로젝트는 RTL 지원 없음" |
| `reference` | 외부 시스템 포인터 | "고객 데이터는 Snowflake `customers_v2` 테이블" |

---

## 작성 / 조회 규칙

### 새 메모리 작성 시
1. `valid_from` 반드시 명시 (오늘 날짜 기본값)
2. `valid_until` 은 `null` (현재 유효)
3. 같은 주제의 기존 메모리 있으면 `supersedes` 에 추가 + 기존 메모리에 `valid_until` 설정

### 메모리 조회 시
1. `valid_until` 이 오늘 이전 → "stale" 표시, advisory로만 사용
2. `supersedes` 체인 따라 **최신 버전 우선**
3. `confidence < 0.5` 메모리는 "low confidence" 경고

### 메모리 evolution (주기적)
- 분기마다 `valid_from` 이 12개월+ 지난 메모리 review
- 연관 메모리 추가 시 기존 메모리의 `tags` / `description` 갱신 (A-MEM 패턴)

---

## v1 → v2 마이그레이션 (점진)

**기존 v1 메모리는 그대로 동작합니다** (v2 필드 모두 선택사항). 점진 마이그레이션:

1. **새 메모리부터 v2 frontmatter로** 작성 — 자동 적용
2. **중요 v1 메모리만 review하며** `valid_from`, `tags` 추가 — 한 번에 다 안 해도 됨
3. **기존 메모리 무효화 시** `supersedes` + 새 메모리에 `valid_until` 갱신

---

## 참고 자료

- [Zep — A Temporal Knowledge Graph Architecture (arXiv 2501.13956)](https://arxiv.org/abs/2501.13956)
- [A-MEM — Agentic Memory for LLM Agents (arXiv 2502.12110)](https://arxiv.org/abs/2502.12110)
- [State of AI Agent Memory 2026 — Mem0](https://mem0.ai/blog/state-of-ai-agent-memory-2026)
- [Anthropic Memory Tool docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool)
- [Graphiti — Neo4j blog](https://neo4j.com/blog/developer/graphiti-knowledge-graph-memory/)

---

## 예제 메모리

[`examples/feedback-2026-05-14-budget-aware-coding.md`](./examples/feedback-2026-05-14-budget-aware-coding.md) — 실제 사용된 v2 메모리 예시.
