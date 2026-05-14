---
name: spec-driven
description: 기능 구현 전 SPEC 문서로 요구사항·엣지케이스·검증기준·롤백 계획을 먼저 정리하는 skill. "코드부터 쓰기 시작"을 차단하고 대화 앵커를 만들어 세션이 길어져도 논지가 흐트러지지 않게 한다. 신규 feature, 버그 수정, 리팩토링, 마이그레이션 등 비trivial 작업 시 자동 사용.
when-to-use: 새 feature/refactor 시작 시 / 여러 파일 변경이 예상될 때 / 엣지케이스가 중요한 버그 수정 / 마이그레이션·데이터 변경
---

# Spec-Driven Development — "Waterfall in 15 Minutes"

## 배경

Addy Osmani (2026): *"대규모 모놀리식 프롬프트는 10명이 서로 안 보고 만든 것
같은 혼돈을 낳는다. 15분 waterfall이 15시간 디버깅을 아낀다."*

Anthropic 공식 best practices: *"Spec은 persistent memory의 일부가 되어야 한다."*

## 동작 방식

이 skill이 발동되면:

1. `docs/_drafts/SPEC-<slug>-<YYYY-MM-DD>.md` 경로에 `SPEC_TEMPLATE.md` 기반 문서 생성
2. 사용자와 함께 5개 필드(요구사항·인터페이스·엣지케이스·검증·롤백) 채움
3. 저장 후 **구현 시작 — 이후 모든 대화는 이 SPEC을 앵커로 참조**
4. 구현 완료 시 SPEC 하단에 `## Outcome` 섹션 자동 추가, 메모리(MEMORY.md)에 링크 누적

## 실행 순서 (에이전트 지시)

```
Step 1. SPEC 슬러그 결정 (기능명 kebab-case)
Step 2. SPEC_TEMPLATE.md를 읽어 새 SPEC 파일에 복사
Step 3. 사용자에게 5개 필드 순차 질문 (각 필드 1~2문장으로 채움)
  - 요구사항 (What + Why)
  - 인터페이스 (API shape / UI contract)
  - 엣지케이스 (최소 3개)
  - 검증기준 (어떤 테스트로 통과 판정할지)
  - 롤백 전략 (실패 시 되돌리는 방법)
Step 4. SPEC 저장 후 Plan Mode로 전환
Step 5. 구현 후 Outcome 섹션에 실제 결과 + 남은 이슈 기록
Step 6. MEMORY.md에 `- [YYYY-MM-DD] <slug>: <1줄 요약> → docs/_drafts/SPEC-...` 추가
```

## 탈출 조건 (skill 발동 안 하는 경우)

- 단일 파일 단일 라인 수정 (typo, rename)
- 명백한 하드 버그 fix (스택 트레이스가 root cause를 바로 지목)
- 사용자가 명시적으로 "빨리", "skip spec" 요구

## 참고

- [Addy Osmani — My LLM Coding Workflow Going into 2026](https://addyosmani.com/blog/ai-coding-workflow/)
- [Anthropic — Claude Code Best Practices](https://code.claude.com/docs/en/best-practices)
- `~/.claude/rules/spec-driven.md` — 저장 경로·규칙
- `./SPEC_TEMPLATE.md` — 복사용 템플릿
