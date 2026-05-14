---
name: codex-harness-v6
description: Unified Codex harness guidance for 2026-05 agent operations. Use for budget gates, model routing, tool deduplication, LLM-as-Judge, prompt-cache monitoring, OpenTelemetry traces, temporal memory, MCP/skill security, and evaluating whether Claude Code hooks should be adapted to Codex.
---

# Codex Harness v6

This skill is the Codex-native adapter for the unified `codex_skill` setup.
It merges the legacy Claude Code skillpack with the newer 2026-05 harness materials from `hyunseung-aicx/claude_skill`.

## Resource Map

- `skills/` - Codex-discoverable task skills.
- `commands/` - Claude-style slash command references, interpreted through native Codex tools.
- `agents/` - role briefs. Use Codex subagents only when current instructions and the user request permit delegation.
- `rules/` - focused rule packs. Load only the relevant rule files for the task.
- `hooks/` - deterministic shell helpers and Claude Code hook scripts. Treat as reference or manually runnable helpers unless adapted.
- `memory-schema/` - temporal memory frontmatter pattern.
- `settings/settings.example.json` - Claude Code hook example, not direct Codex config.
- `docs/2026-05-14-research-scorecard.md` - evidence-backed evaluation.
- `docs/unified-integration-report.md` - comparison and integration decisions.

## Operating Rules

1. Codex system/developer instructions always win over this skillpack.
2. Prefer Codex-native controls: sandbox permissions, approvals, MCP config, `AGENTS.md`, skills, and OpenTelemetry config.
3. Do not automatically wire Claude Code hooks into Codex. Codex does not expose the same hook lifecycle.
4. Treat hook scripts as one of three classes:
   - `portable`: safe to run manually with a known JSON stdin contract.
   - `codex-adaptable`: useful pattern, but path/schema changes are required.
   - `claude-only`: keep as reference.
5. Any gate that can block work starts in `warn` mode before `block` mode.
6. Any script that reads credentials, calls external APIs, or writes outside the project must be explicit to the user.
7. For security-sensitive tasks, consult OWASP Agentic Top 10, MCP threat taxonomy, and skill supply-chain notes in the scorecard.

## Harness Layers

Use this order when designing or reviewing an agent workflow:

1. Goal and scope: define the task, allowed repositories, and expected artifacts.
2. Context: load `AGENTS.md`, relevant skills, local files, Jira/Confluence/GitHub context, and only the needed rules.
3. Tool governance: select tools deliberately, separate read/write actions, and preserve approval boundaries.
4. Execution: implement in small verifiable steps, keep worktree changes scoped, and log meaningful decisions.
5. Verification: run deterministic tests first, then use evaluator/judge workflows for subjective or multi-agent output.
6. Observability: capture prompts, tool calls, approvals, tests, cost/latency, and final evidence where available.
7. Memory: write durable facts with temporal metadata when the user asks to preserve knowledge.

## Codex Mapping for v6 Hooks

| v6 asset | Codex status | Recommendation |
| --- | --- | --- |
| `budget-gate.sh` | codex-adaptable | Convert paths from `.claude` to project/Codex trace paths before automation. |
| `tool-hash-dedup.sh` | codex-adaptable | Use as loop detector pattern; Codex tool events need a wrapper/export source. |
| `model-router-v2.sh` | advisory | Use as a reasoning aid; actual model choice follows available Codex controls. |
| `tool-selector.sh` | portable/advisory | Use to narrow MCP/tool categories before loading context. |
| `llm-judge.sh` | codex-adaptable | Requires API key and diff context; run only when user wants judging. |
| `otel-trace-exporter.sh` | codex-adaptable | Align with Codex OTel logs and OpenTelemetry GenAI conventions. |
| `prompt-cache-monitor.sh` | claude-only/reference | Keep as a prompt caching pattern unless Codex transcript fields match. |
| `bench-runner.sh` | codex-adaptable | Prefer Codex automation or CI once benchmark tasks exist. |
| `judge-agent.md` | portable role brief | Use for final review consolidation, with evidence-only verdicts. |
| `memory-schema/` | portable | Use temporal frontmatter for durable memory notes and project decisions. |

## Scoring Rubric

When evaluating this setup, score each area from 0-10:

- Skill portability and discoverability
- Harness execution flow
- Tool/MCP governance
- Observability and replay
- Evaluation and judge quality
- Memory and context hygiene
- Security and supply-chain controls
- Install/update ergonomics

Use `docs/2026-05-14-research-scorecard.md` as the canonical scorecard.
