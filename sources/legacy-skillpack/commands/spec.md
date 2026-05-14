---
description: Spec-driven workflow 시작. 신규 feature/refactor/migration 전에 SPEC 문서를 먼저 작성하여 요구사항·엣지케이스·검증기준을 명확히 한다. "waterfall in 15 minutes".
---

# /spec

## 사용법

```
/spec <기능 또는 작업 설명>
```

예:
- `/spec 모바일 헤더에 검색 아이콘 추가`
- `/spec ClickHouse events 테이블에 utm_source 컬럼 추가`
- `/spec legacy auth middleware → JWT 마이그레이션`

## 동작

1. `spec-driven` skill을 발동시킴
2. `~/.claude/skills/spec-driven/SPEC_TEMPLATE.md`를 기반으로 `docs/_drafts/SPEC-<slug>-<YYYY-MM-DD>.md` 생성
3. 사용자와 5개 필드 채움 (요구사항/인터페이스/엣지/검증/롤백)
4. 완료 후 Plan Mode로 전환 또는 `/plan` 호출
5. 구현 후 `## Outcome` 섹션 업데이트 + MEMORY.md에 링크 추가

## 언제 쓰면 좋은가

- 신규 기능 추가
- 여러 파일 수정이 예상되는 리팩토링
- 엣지케이스 많은 버그 수정
- 스키마 변경·마이그레이션·데이터 변환
- 라이브러리 전환·업그레이드

## 언제 쓰지 않는가

- 단일 파일 typo, rename
- 명확한 단일 fix (예: null 체크 추가)
- 사용자가 "빨리" / "skip spec" 명시

## 연관

- 규칙: `~/.claude/rules/spec-driven.md`
- 스킬: `~/.claude/skills/spec-driven/SKILL.md`
- 템플릿: `~/.claude/skills/spec-driven/SPEC_TEMPLATE.md`
- 후속: `/plan` (구현 전략) → 구현 → `/code-review` → commit
