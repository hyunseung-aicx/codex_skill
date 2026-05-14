# codex_skill

This repository exports the **sanitized Codex setup recognized on this Mac** and adds a research-backed playbook for FDE/Product Engineer workflows.

It does **not** include auth/session/log/cache files from `~/.codex`.

## Actual Export

| Path | What it contains |
| --- | --- |
| `codex-export/config/config.sanitized.toml` | sanitized global Codex config |
| `codex-export/SKILLS_INVENTORY.md` | system/plugin/vendor skill inventory |
| `codex-export/vendor-skills/My_ClaudeCode_Skill/skills/` | exported vendor skill files |
| `codex-export/DO_NOT_EXPORT.md` | files intentionally excluded for security |
| `apps/personal-work-assistant/` | local Jira/Confluence/GitHub dashboard MVP |

## Why This Exists

FDE(Product Engineer) 관점에서 Codex를 단순 코드 생성기가 아니라 **업무 실행 하네스(Work Harness)** 로 쓰기 위한 셋업입니다.

핵심 목표는 다음입니다.

- Jira, Confluence, GitHub, 로컬 레포를 하나의 업무 맥락으로 묶는다.
- 고객 문제를 제품 기획, 시스템 설계, 구현, 검증, 운영 문서로 연결한다.
- Skill, MCP, tool governance, human-in-the-loop를 통해 안전하게 실행한다.
- 2026년 기준 agent engineering 연구 흐름에 맞춰 평가 가능하고 관측 가능한 구조로 발전시킨다.

## Additional Playbook Docs

| Path | Purpose |
| --- | --- |
| `docs/00-executive-summary.md` | 사내 AI 세션용 요약 |
| `docs/01-skill-engineering.md` | Skill Engineering 원칙 |
| `docs/02-harness-engineering.md` | Codex Harness 설계 |
| `docs/03-tool-governance.md` | 도구 권한, 승인, 보안 규칙 |
| `docs/04-fde-product-engineer-workflows.md` | FDE/PE 업무 워크플로우 |
| `docs/05-2026-research-evaluation.md` | 2026 연구 기반 평가와 점수 |
| `docs/06-roadmap.md` | 다음 단계 로드맵 |
| `examples/AGENTS.md` | 레포별 Codex 컨텍스트 파일 예시 |
| `examples/skills/` | 커스텀 스킬 예시 |
| `codex-export/REPRODUCE.md` | 다른 PC에서 재현할 때 필요한 절차 |

## Core Message

> 2026년 AI 활용의 차이는 프롬프트가 아니라, AI가 안전하게 도구를 쓰고 맥락을 읽고 반복 가능한 방식으로 일하게 만드는 Skill & Harness Engineering에 있다.

## Architecture

```text
User Request
  -> Skill Router
  -> Context Layer
     - AGENTS.md
     - Jira
     - Confluence
     - GitHub
     - Local repositories
  -> Tool Harness
     - filesystem
     - shell
     - browser
     - MCP tools
  -> Permission Layer
     - read-only by default
     - approval for write/deploy/destructive actions
  -> Verification Loop
     - tests
     - screenshots
     - API checks
     - PR/Jira evidence
```

## Local Dashboard

```bash
cd apps/personal-work-assistant
cp .env.example .env
node server.js
```

Open:

```text
http://127.0.0.1:4173
```

It is read-only by design unless write actions are explicitly added later.

## Research-Informed Score

Current setup score as of 2026-05-14:

```text
7.2 / 10
```

Strong:

- Skill stack for FDE/Product Engineer workflows
- MCP-based enterprise context access
- Local code/repo/browser execution harness
- Human-in-the-loop posture

Needs work:

- Agent observability and traces
- Skill evaluation datasets
- Structured long-term memory
- MCP/security hardening
- Repo-level `AGENTS.md` standardization

See `docs/05-2026-research-evaluation.md`.

## Recommended Talk Title

```text
Prompt Engineering 이후:
FDE/Product Engineer를 위한 Codex Skill & Harness Engineering
```
