# Hermes Patterns for Codex

Date: 2026-05-15

## Why Hermes Matters

Hermes Agent is not just another chatbot wrapper. Its interesting contribution is an operating model for a persistent agent:

- durable memory
- procedural skills
- skill curation
- background/gateway operation
- multi-agent coordination
- self-improvement loops

Codex has a different center of gravity: it is a development agent that works directly in repositories through GUI and terminal. The right move is not to copy Hermes wholesale, but to port the useful harness patterns into Codex-native primitives.

## Research and Case Signals

| Signal | What it implies for Codex |
| --- | --- |
| Hermes Agent skills and curator releases | Skills need lifecycle management, not just accumulation. |
| Long-running agent harness work | Long tasks need durable state, resumable prompts, branch/worktree isolation, and evaluator loops. |
| Agent-computer interface research | Purpose-built commands improve agent reliability by giving structured affordances. |
| Terminal-Bench harness improvements | Harness design can move benchmark outcomes even when the model is fixed. |
| Skill/security supply-chain research | Skills, hooks, and MCP servers are executable operational inputs and need trust review. |
| OpenAI Codex `/goal` | Long-running objective tracking is becoming a first-class coding-agent workflow. |

Sources:

- https://github.com/NousResearch/hermes-agent
- https://hermes-agent.nousresearch.com/docs/
- https://newreleases.io/project/github/NousResearch/hermes-agent/release/v2026.4.30
- https://arxiv.org/abs/2605.13357
- https://openai.com/index/unrolling-the-codex-agent-loop/
- https://developers.openai.com/codex/cli/slash-commands
- https://www.langchain.com/blog/improving-deep-agents-with-harness-engineering
- https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

## Pattern Translation

| Hermes pattern | Codex-native translation | Added here |
| --- | --- | --- |
| Persistent memory | `memory` MCP, temporal memory schema, memory audit | `scripts/codex-memory-audit.sh` |
| Skill curator | Metadata, size, duplication, staleness, and risk scan | `scripts/codex-skill-curator.sh` |
| Skill drift detection | Warn when skills/rules/hooks change without docs | `hooks/skill-drift-checker.sh` |
| Multi-agent board | File-backed board for planner/worker/reviewer/judge states | `progress/BOARD.md` |
| Long-running objective | Codex `/goal` plus local goal packets and worktrees | `docs/goal-long-run-methodology.md` |
| Self-improvement loop | Run curator/audit after goals and turn findings into small PRs | `scripts/` + board policy |
| Gateway operation | Slack/MCP and Codex automations, not unrestricted daemon control | policy only |

## Operating Principle

Hermes-style autonomy is useful only when paired with friction in the right places:

- easy to continue work
- easy to inspect what changed
- hard to destroy data
- hard to silently grow stale skills
- hard to forget why a decision was made

For Codex, that means the self-improving loop should produce reviewable files and commits rather than silently rewriting the harness.

## Weekly Curator Loop

Run:

```bash
scripts/codex-skill-curator.sh
scripts/codex-memory-audit.sh
```

Then:

1. Review `progress/SKILL_CURATOR.md`.
2. Review `progress/MEMORY_AUDIT.md`.
3. Move proposed changes into `progress/BOARD.md`.
4. Use `/goal` for any multi-hour cleanup.

## What Not To Port

Do not port these Hermes patterns directly:

- unrestricted background shell access
- automatic credential use
- autonomous production DB/cloud writes
- unreviewed skill deletion or rewrite
- broad memory writes without source/confidence/expiry

Codex should keep human approval and repository review as the final control plane.
