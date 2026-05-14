# Error Debugging Discipline — 주니어×AI 디버깅 표준

globs: ['**/*']

> 에러는 **학습 데이터**다. 부끄러워하지 말고, 단계적으로 함께 분석한다.

## 핵심 원칙 (ALWAYS)

**에러 발생 시 즉시 fix 금지. 분해 먼저.**

`error-recovery` skill을 자동 발동시켜 **5단 표준 흐름**을 따른다:

```
① REPRODUCE  ② DIAGNOSE  ③ OPTIONS  ④ DECIDE  ⑤ PREVENT
```

## 자동 발동 조건

다음 시그널 감지 시 `error-recovery` skill이 자동으로 작동:
- 사용자 메시지에 "에러", "안 돼요", "실패", "Error", "Exception", "Traceback"
- 스택 트레이스 형태 (file:line + at 키워드)
- PostToolUseFailure 누적 3+ (failure-explainer.sh / error-context-collector.sh가 알림)
- 빌드·테스트 출력에 `failed`, `FAIL`, `❌`

## 안티패턴 (금지)

| 안티패턴 | 왜 안 좋은가 | 대신 |
|---------|------------|------|
| "고쳐줘" → 즉시 Edit | 근본 원인 모르고 patch → 재발 | 5단 분해 먼저 |
| 스택 첫 줄만 보고 fix | WHERE ≠ 근본 원인 | WHY 2~3단 추적 |
| 1개 옵션만 떠올리고 적용 | trade-off 검토 없음 → 부채 | 3안 비교표 |
| try/catch로 silent swallow | 다음에 더 심한 형태로 재발 | 명시적 처리 + 로깅 |
| 같은 fix 시도 3회+ | doom loop | failure-explainer 경고 → debugger agent 위임 |

## Trade-off 의사결정 표 (DECIDE 단계)

| 상황 | 권장 옵션 |
|------|----------|
| 내일 데모·긴급 출시 | (A) 즉시 패치 + 후속 ticket |
| 데드라인 1주 내 | (B) 우회 + 다음 sprint에 (C) |
| 일반 개발 / 신규 기능 | (C) 근본 fix |
| 이미 같은 버그 2회+ 발생 | (C) 강제 + 재발 방지 훅 |
| 서비스 중단 (P0) | (A) 즉시 → 핫픽스 → 회고 |

## PREVENT 표준 액션 (5단계)

같은 에러를 두 번 만나면 부끄럽다. 첫 발생 시 즉시:

1. **테스트 추가**: 에러 케이스 재현하는 unit test (RED → GREEN)
2. **타입 강화**: 가능하면 컴파일 시점 차단 (TS strict, branded types)
3. **린터 룰**: ESLint custom rule 또는 `no-restricted-syntax`
4. **훅 추가**: PreToolUse / PostToolUse 훅으로 패턴 차단
5. **문서화**: `MEMORY.md`에 사례 + 해결법 1줄

## 도구 매핑

| 도구 | 역할 |
|------|------|
| `error-recovery` skill | 5단 흐름 가이드 |
| `error-context-collector.sh` 훅 | 실패 시 자동 컨텍스트 수집 (cwd, git, 최근 변경 파일) |
| `failure-explainer.sh` 훅 | Bash 실패 패턴 분류 + 가이던스 |
| `debugger` agent | 5단 흐름이 막히거나 3회+ 실패 시 위임 |
| `cs-boost.md` 룰 | 에러 분해 5단 표준 (WHAT/WHERE/WHY/FIX/PREVENT) |

## 주니어를 위한 한 줄

> *"AI에게 '왜 안 되지'라고 묻기 전에, 본인이 먼저 5단 분해를 해보세요.
> 그 분해 자체가 90% 답을 알려줍니다. 나머지 10%만 AI에게."*

## 참고

- HumanLayer — *Harness Engineering*
- Debugger agent — `~/.claude/agents/debugger.md`
- error-recovery skill — `~/.claude/skills/error-recovery/SKILL.md`
