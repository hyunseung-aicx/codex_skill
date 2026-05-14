# codex_skill

Unified Codex GUI/terminal setup for this Mac, built on 2026-05-14 research and the local Claude/Codex skillpack inventory.

This repo merges:

- the currently installed `My_ClaudeCode_Skill` Codex adapter stack
- `hyunseung-aicx/claude_skill` Harness v6
- a Codex-native install, doctor, update, and evaluation layer

It intentionally excludes auth/session/log/cache files from `~/.codex`.

## Current Verdict

```text
Score: 9.3 / 10
Grade: A-
Date: 2026-05-14
```

Why not A+ yet:

- Claude Code hooks are merged as reference/adaptable scripts, not silently auto-wired into Codex.
- Internal benchmark/eval data is not yet included.
- Codex-native OTel endpoint config still needs to be selected.
- GitHub/Sentry/Figma MCPs require user-side auth or desktop runtime state before full use.

See [docs/2026-05-14-research-scorecard.md](docs/2026-05-14-research-scorecard.md).

## What Is Included

| Path | Purpose |
| --- | --- |
| `skills/` | Codex-discoverable skills, including `codex-harness-v6`. |
| `commands/` | Claude-style slash command briefs interpreted through Codex tools. |
| `agents/` | Role briefs, including `judge-agent.md`. |
| `rules/` | Focused rule packs for coding, security, testing, workflow, MCP, and harness behavior. |
| `hooks/` | Deterministic helper scripts and Claude Code hook assets. Reference/adapt before automation. |
| `memory-schema/` | Temporal memory pattern from Harness v6. |
| `settings/` | Claude settings example and future Codex settings examples. |
| `scripts/` | Setup, doctor, update, goal runner, and migration helpers. |
| `docs/unified-integration-report.md` | Existing-vs-new comparison and merge decisions. |
| `docs/dangerous-command-guardrails.md` | Destructive-command block policy and safe alternatives. |
| `docs/mcp-developer-stack.md` | Frontend/dev MCP stack and usage policy. |
| `sources/` | Full source snapshots used to create the unified setup. |
| `codex-export/` | Sanitized export of the original local Codex setup. |
| `apps/personal-work-assistant/` | Read-only local dashboard MVP from the earlier export. |

## Install For Codex GUI/CLI

```bash
./setup_codex.sh
```

Then restart Codex GUI/CLI or open a new session so skill metadata is reloaded.

Health check:

```bash
~/.codex/bin/codex-skillpack-doctor
```

Update from this repo after pulling:

```bash
~/.codex/bin/codex-skillpack-update
```

## Active vs Reference

Active after install:

- `skills/**/SKILL.md`
- `codex-harness-v6`
- `codex-claude-skillpack`
- maintenance commands under `~/.codex/bin`
- symlinked command/rule/agent resources under `~/.codex/claude-skillpack`

Reference/adaptable:

- Claude Code lifecycle hooks in `hooks/`
- `settings/settings.example.json`
- `llm-judge.sh`, because it requires an API key and explicit invocation
- OTel exporter until a Codex trace endpoint is configured
- benchmark runner until benchmark tasks exist

## Research Basis

The final scorecard uses current sources around:

- OpenAI Codex safety, agent loop, skills, sandboxing, and telemetry
- Anthropic long-running harness and three-agent harness design
- LangChain Terminal-Bench harness engineering and eval design
- OWASP Agentic Top 10 2026
- OpenTelemetry GenAI conventions
- Zep temporal memory
- Agent-as-a-Judge
- MCP and skill supply-chain security research
- Playwright MCP, Chrome DevTools MCP, Figma Dev Mode MCP, OpenAI Docs MCP, Context7, GitHub, Filesystem, Memory, Prisma, Sentry, and project-scoped DB MCP docs

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

## Core Principle

2026 agent performance is not only about the model. It is about the harness: skills, scoped context, tool governance, verification, observability, memory, and human approval boundaries.
