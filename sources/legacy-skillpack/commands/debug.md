---
description: 에러·실패에 대해 5단 분해(REPRODUCE → DIAGNOSE → OPTIONS → DECIDE → PREVENT)를 진행. 주니어가 AI와 함께 디버깅하며 trade-off까지 결정할 수 있도록 안내. error-recovery skill을 명시 발동.
---

# /debug

## 사용법

```
/debug <에러 메시지 또는 스택 트레이스>
```

또는 컨텍스트 없이 그냥 `/debug` — 가장 최근 실패를 자동 식별.

## 동작

1. `error-recovery` skill 발동
2. 5단 표준 흐름 진행:
   - **REPRODUCE**: 한 줄 명령으로 에러 재현
   - **DIAGNOSE**: WHAT / WHERE / WHY 5단 분해
   - **OPTIONS**: 3가지 fix 안 (즉시 / 우회 / 근본) 비교표
   - **DECIDE**: 사용자와 trade-off 합의
   - **PREVENT**: 재발 방지 훅 / 테스트 / 규칙
3. 같은 에러 3회+ 누적 시 자동으로 `debugger` agent에 위임

## 예시

```
/debug TypeError: Cannot read properties of undefined (reading 'map') at src/UserList.tsx:42
```

→ AI가 다음 순서로 응답:
1. 재현 명령 제시 (`npm test -- UserList`)
2. WHAT/WHERE/WHY 5단 분해
3. fix 3안 비교표 (방어 코드 / 데이터 검증 / API 스키마 강화)
4. 사용자에게 어떤 옵션 선택할지 질문
5. 선택 후 적용 + 재발 방지 (단언문 추가, 테스트 추가)

## 언제 쓰면 좋은가

- 에러 메시지 / 스택 트레이스 받았을 때
- 빌드·테스트 실패 시
- "왜 안 되지?" 의문 들 때
- 같은 fix를 2번째 시도하기 직전
- 사용자가 trade-off 모르는 채 patch만 하려 할 때

## 언제 쓰지 않는가

- 명백한 typo (찾으면 바로 fix)
- 단순 권한 에러 (sudo, chmod로 즉시 해결)
- 사용자가 "그냥 빨리 고쳐줘"를 명시 (단, 부채 경고는 1줄로 알림)

## 연관

- 룰: `~/.claude/rules/error-debugging.md`
- 룰: `~/.claude/rules/cs-boost.md` (에러 5단 분해 원형)
- 스킬: `~/.claude/skills/error-recovery/SKILL.md`
- 에이전트: `~/.claude/agents/debugger.md`
- 훅: `~/.claude/hooks/error-context-collector.sh`, `failure-explainer.sh`
