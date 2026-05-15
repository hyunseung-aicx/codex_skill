# Agent Board

Updated: 2026-05-15

This board tracks durable Codex harness work. Keep items short and move them as evidence changes.

## Active

- [ ] Enable `/goal` globally and document Ralphthon workflow.
- [ ] Add Hermes-style skill curator and memory audit scripts.
- [ ] Add skill drift hook for changes to `skills/`, `rules/`, `hooks/`, and `commands/`.

## Backlog

- [ ] Add 20-task internal benchmark under `benchmarks/`.
- [ ] Add OTel Collector + Phoenix local trace recipe.
- [ ] Add project-scoped Postgres/Supabase/Neon MCP examples with dev/staging credential policy.
- [ ] Add GitHub/Sentry auth verification checklist.
- [ ] Add Slack gateway automation pattern for safe status notifications.

## Review

- [ ] Confirm curator reports are readable and low-noise.
- [ ] Confirm `/goal` packet flow works in both GUI and terminal.

## Done

- [x] Unified Codex skillpack and Harness v6.
- [x] Added core MCP developer stack.
- [x] Added dangerous command guardrails.
- [x] Added MCP developer stack documentation.

## Rules

- Every active item needs a verification path.
- Move stale active items back to backlog after 14 days.
- Long-running work should create `.codex-goals/<goal-id>/STATUS.md`.
- Curator findings should become small board items, not silent rewrites.
