---
name: error-recovery
description: 에러 발생 시 주니어와 AI가 함께 단계적으로 분석·재현·디버깅·트레이드오프 결정을 진행하는 skill. 단순 "고쳐줘" 요청을 받았을 때 자동 발동하여 5단 분해 + 3가지 fix 옵션 비교 + 재발 방지 훅 제안까지 풀 사이클을 안내한다. 주니어가 AI에 의존하기보다 함께 사고하도록 유도.
when-to-use: 에러 메시지 / 스택 트레이스 / "안 돼요" / "왜 이래" / 빌드 실패 / 테스트 실패 / 런타임 에러 보고 시 자동 발동
---

# Error Recovery Coach — 주니어×AI 디버깅 동행

## 배경

주니어 개발자가 AI에게 에러를 던지면 흔히 발생하는 4가지 문제:

| 문제 | 결과 |
|------|------|
| 1. 재현 절차를 모름 | 다른 환경에서 fix가 안 통함 |
| 2. 어떤 로그가 중요한지 모름 | 잘못된 단서로 AI 유도 |
| 3. fix 옵션이 1개만 떠올림 | trade-off 검토 없이 patch → 부채 누적 |
| 4. 같은 실수 반복 | 훅·규칙으로 막지 않으면 재발 |

이 skill은 4가지 모두 자동 가이드.

## 발동 조건

다음 시그널 감지 시 자동 발동:
- 사용자 메시지에 "에러", "안 돼", "실패", "Error", "Exception", "Traceback" 포함
- 스택 트레이스 형태 (file:line 패턴 + at 키워드)
- PostToolUseFailure 훅이 누적 카운트 3+ 알림
- 빌드/테스트 결과에 `failed`, `FAIL`, `❌` 포함

## 5단 표준 흐름

```
① REPRODUCE  : 에러를 한 줄 명령으로 재현
② DIAGNOSE   : WHAT / WHERE / WHY 5단 분해
③ OPTIONS    : 3가지 fix 안 (즉시/우회/근본) 비교
④ DECIDE     : 사용자와 trade-off 합의 후 적용
⑤ PREVENT    : 재발 방지 훅·테스트·규칙
```

### Step ① REPRODUCE — 한 줄 명령으로 재현

목표: 다음 turn에서도 동일한 에러를 100% 재현 가능하게.

```bash
# 예시 (Node)
npm test -- src/foo.test.ts --reporter=verbose

# 예시 (Python)
pytest tests/test_foo.py::test_bar -xvs

# 예시 (curl)
curl -i -X POST http://localhost:8080/api/foo -d '{"x":1}'
```

재현 안 되면 → 환경 차이 의심 (node 버전, env vars, DB 상태). 환경 sniff 우선.

### Step ② DIAGNOSE — 5단 분해 (`cs-boost.md`와 짝)

```
🔍 에러 분해:
   WHAT   : <에러 메시지 핵심 1줄>
   WHERE  : <file:line 또는 스택 최상단>
   WHY    : <"왜?" 2~3번 묻고 답> — 단순 증상 ≠ 근본 원인
   STACK  : <관련된 스택 3프레임 인용>
   STATE  : <관련 변수/입력 값 정확히>
```

**WHY가 1단으로 끝나면 의심**: 더 깊이 파라.

### Step ③ OPTIONS — 3가지 fix 안

| 옵션 | 시간 | 위험 | 부채 | 적합 상황 |
|------|------|------|------|----------|
| (A) 즉시 패치 | 10분 | 낮음 | 누적 | 데모·긴급 출시 |
| (B) 우회 | 30분 | 중간 | 일시적 | 데드라인 압박 |
| (C) 근본 fix | 2~6시간 | 높음 | 해소 | 일반적 권장 |

각 옵션마다:
- **변경 범위**: 몇 파일?
- **테스트 영향**: 새 테스트 필요?
- **롤백 방법**: revert 가능?

### Step ④ DECIDE — 사용자와 합의

옵션 1개 선택은 **사용자**가. AI는 trade-off 표만 제시.

권장 질문:
- *"이 PR이 stage 환경 검증 후 merge되나요? 그러면 (C) 권장."*
- *"내일 데모면 (A) → 이번 주 안에 (C)로 follow-up 티켓."*

### Step ⑤ PREVENT — 같은 실수 막기 (메타-하네스)

| 실수 유형 | 방지 도구 |
|----------|----------|
| 타입 미스매치 | TS strict + `tsc-check.sh` 훅 |
| 미체크 null/undef | ESLint `no-non-null-assertion` |
| 환경변수 누락 | startup validation (zod) |
| 동시성 race | 테스트 + linter rule |
| 회귀 (이전에 고쳤던 것) | regression test 추가 → CI |

`/learn` 또는 `instinct-export`로 패턴 승격.

## 출력 형식 (사용자에게 보여줄 때)

```
## 🔍 에러 분해
- WHAT: ...
- WHERE: ...
- WHY (3단): ① ... ② ... ③ ...

## 🔁 재현
$ <한 줄 명령>

## ⚖️ Fix 옵션 비교
| 옵션 | 변경 | 위험 | 시간 | 부채 |
|------|------|------|------|------|
| A 즉시 | ... | 낮음 | 10분 | 있음 |
| B 우회 | ... | 중간 | 30분 | 임시 |
| C 근본 | ... | 높음 | 4h | 없음 |

추천: <옵션> — 근거: <상황>

## 🛡️ 재발 방지
- ... (훅/테스트/규칙 1~2개)
```

## 안티패턴 (금지)

- 사용자가 "고쳐줘" 한 마디에 즉시 Edit/Write
  → **5단 분해 + 옵션 비교가 먼저**
- 옵션 (A) 즉시 패치 후 PREVENT 단계 생략
  → 같은 버그 3개월 후 재발
- 스택 트레이스 첫 줄만 보고 fix
  → "WHERE는 발생 지점, ROOT는 다른 곳"이 흔함

## 참고

- `~/.claude/rules/cs-boost.md` — 에러 5단 분해 표준
- `~/.claude/rules/error-debugging.md` — 본 skill의 강제 적용 룰
- `~/.claude/agents/debugger.md` — 더 깊은 디버깅이 필요할 때 위임
- `~/.claude/hooks/error-context-collector.sh` — 자동 컨텍스트 수집
- HumanLayer — *"engineer a solution so the agent never makes that mistake again"*
