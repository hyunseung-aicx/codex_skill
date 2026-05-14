# Spec-Driven Development — 규칙

globs: ['**/*']

## 핵심 원칙 (ALWAYS)

**비trivial 변경은 SPEC 없이 시작하지 않는다.**

비trivial = 아래 중 하나라도 해당:
- 여러 파일 수정 예상
- 새 테이블/엔드포인트/의존성 추가
- UX에 영향을 주는 변경
- 마이그레이션 / 데이터 변환
- 엣지케이스가 중요한 버그 수정

trivial (SPEC 생략 OK):
- 단일 라인 typo / rename
- 명확한 단일 fix (스택 트레이스가 바로 지목)

## 저장 경로

- **위치**: `docs/_drafts/SPEC-<slug>-<YYYY-MM-DD>.md`
- **템플릿**: `~/.claude/skills/spec-driven/SPEC_TEMPLATE.md`
- **커밋**: SPEC은 구현 PR과 동일 커밋에 포함 (구현 직후 `## Outcome` 채워서)

## 자동 발동

다음 명령 실행 시 `spec-driven` skill이 자동 발동:
- `/plan`
- "feature 구현" / "refactor" / "migration" 키워드 포함된 사용자 요청

사용자가 `skip spec` 또는 `빨리`를 명시하면 생략.

## 체크리스트 (구현 전)

- [ ] SPEC 5필드 모두 채워짐 (요구사항·인터페이스·엣지·검증·롤백)
- [ ] 엣지케이스 최소 3개
- [ ] 검증 명령 또는 테스트 케이스가 실행 가능한 형태로 명시
- [ ] 롤백 방법이 구체적 (단순 "revert" 아님)

## 체크리스트 (구현 후)

- [ ] `## Outcome` 채워짐 (실제 결과 / 남은 TODO)
- [ ] PR 링크 추가
- [ ] MEMORY.md에 1줄 요약 + SPEC 경로 append

## Anti-pattern (금지)

- "생각한 대로 만들어줘" + 즉시 Edit/Write  
  → SPEC 없으면 Plan Mode 먼저
- SPEC 작성 후 내용을 모른 채 구현만 진행  
  → 구현 중 SPEC 6번 필드(영향 파일)를 계속 업데이트
- SPEC은 작성하고 Outcome 안 채움  
  → 후속 세션이 "왜 이렇게 구현됐지?" 되물으며 재탐색 비용 발생

## 참고

- [Addy Osmani — waterfall in 15 minutes](https://addyosmani.com/blog/ai-coding-workflow/)
- Anthropic Best Practices — *"Spec becomes part of persistent memory"*
- `~/.claude/skills/spec-driven/SKILL.md`
