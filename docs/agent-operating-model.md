# Agent Operating Model

Date: 2026-05-15

## Purpose

This document defines how Codex should operate as a development agent system rather than a one-shot code assistant.

The model combines:

- Codex skills
- rules
- command briefs
- hooks
- MCP
- `/goal`
- durable progress files
- evaluator/judge loops
- curator scripts

## Roles

| Role | Responsibility | Local resource |
| --- | --- | --- |
| Planner | Decompose goals, define verification, identify risks | `agents/planner.md`, `/plan`, `/goal` |
| Worker | Implement scoped slices | Codex GUI/terminal, skills |
| Reviewer | Find correctness/security/regression issues | `agents/code-reviewer.md`, `security-reviewer.md` |
| Judge | Consolidate evidence into go/no-go | `agents/judge-agent.md` |
| Curator | Improve skills/rules/memory after work | `scripts/codex-skill-curator.sh`, `scripts/codex-memory-audit.sh` |
| Operator | Owns final approvals, credentials, production access | human user |

## State Files

| File | Purpose |
| --- | --- |
| `progress/BOARD.md` | Persistent agent board. |
| `.codex-goals/<goal-id>/STATUS.md` | Per-goal execution status. |
| `progress/SKILL_CURATOR.md` | Skill health report. |
| `progress/MEMORY_AUDIT.md` | Memory/context hygiene report. |
| `docs/goal-long-run-methodology.md` | `/goal` operating guide. |
| `docs/hermes-patterns-for-codex.md` | Hermes-to-Codex pattern translation. |

## Standard Work Loop

```text
Intake
  -> classify task
  -> select skills/rules/MCP
  -> choose normal vs /goal mode
  -> branch/worktree
  -> inspect
  -> plan
  -> implement slice
  -> verify
  -> update status/board
  -> review/judge
  -> commit/push or handoff
  -> curator/audit if long-running
```

## When To Use `/goal`

Use `/goal` when:

- the task can run for 1+ hour
- there are multiple implementation slices
- the user wants background/autonomous progress
- work may span GUI and terminal
- context loss would be costly
- worktree isolation is helpful

Do not use `/goal` for:

- one-line fixes
- high-risk production actions
- unclear product decisions
- tasks that need immediate human interaction

## MCP Selection

| Need | MCP |
| --- | --- |
| Jira/Confluence context | `atlassian` |
| Frontend UI state | `playwright` |
| Browser console/network/perf | `chrome-devtools` |
| Design context | `figma-desktop` |
| GitHub issues/PRs/repos | `github` |
| Sentry production errors | `sentry` |
| Framework/library docs | `context7` |
| OpenAI/Codex docs | `openaiDeveloperDocs` |
| Durable facts | `memory` |
| Prisma local workflows | `prisma-local` |

## Safety Rules

1. Run deterministic verification before subjective judgment.
2. Do not run destructive commands automatically.
3. Never store secrets in memory.
4. Keep DB MCP credentials project-scoped and dev/staging by default.
5. Keep Figma/GitHub/Sentry auth explicit.
6. Update durable state before any long pause.
7. Prefer small commits that explain harness changes.

## Curator Cadence

| Cadence | Action |
| --- | --- |
| After every `/goal` | update `STATUS.md`, run targeted verification |
| Weekly | run skill curator and memory audit |
| Monthly | archive stale progress, review MCP list, review dangerous command patterns |
| Before release | run doctor, diff check, security review, judge review |

## Success Metric

The agent operating model is healthy when:

- a new session can resume from files without chat history
- a reviewer can understand why changes happened
- dangerous operations are blocked or routed to approval
- skills improve without uncontrolled sprawl
- memory becomes more accurate over time, not larger by default
