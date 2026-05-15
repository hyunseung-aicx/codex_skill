# 2026-05-15 Research Scorecard

Date: 2026-05-15

## Verdict

```text
Unified codex_skill score: 9.4 / 10
Grade: A-
```

The setup is strong enough to be used as a daily Codex skill/harness layer. The score increased after adding destructive-command guardrails, a developer MCP stack, native `/goal` enablement, Hermes-style curator scripts, memory audit, and a durable agent board. It is not yet A+ because v6 hooks are merged as reference/adaptable assets rather than fully wired Codex event hooks, GitHub/Sentry/Figma require user-side auth or runtime state, project DB connectors need scoped credentials, and internal eval/benchmark data is not yet present.

## Scorecard

| Area | Score | Evidence-based rationale |
| --- | ---: | --- |
| Skill portability and discovery | 9.3 | Uses Codex-discoverable `skills/**/SKILL.md`; mirrors the Agent Skills folder model. |
| Harness engineering | 9.4 | Combines skills, command briefs, rules, hooks, progress, `/goal`, curator scripts, memory audit, and maintenance scripts. |
| Tool/MCP governance | 9.3 | Adds OpenAI Docs, Playwright, Chrome DevTools, Figma Desktop, Context7, GitHub, Filesystem, Memory, Sentry, Prisma local, Atlassian, and Slack MCP coverage; needs stricter read/write credential separation for DB/cloud writes. |
| Evaluation and judge quality | 8.4 | Adds judge agent, LLM judge hook, verification hooks; needs internal task benchmark. |
| Observability and replay | 8.2 | Adds trace hooks and OTel exporter references; Codex-native OTel config still needs endpoint wiring. |
| Memory and context hygiene | 9.1 | Adds temporal memory schema, Memory MCP policy, memory audit, and scoped context rules; no vector/graph index yet. |
| Security and supply-chain controls | 9.1 | Adds expanded dangerous-command blocker across filesystem, Git, DB, Docker, K8s, IaC, cloud, release, disk, and permission operations. |
| Install/update ergonomics | 9.0 | Reuses `setup_codex.sh`, doctor, update, and symlink strategy for GUI/CLI. |

## Research Findings

### 1. Codex should be governed through native boundaries

OpenAI's Codex safety guidance emphasizes sandbox boundaries, approvals, managed network access, credential handling, rules, and agent-native telemetry. The Codex agent loop also describes how instructions, tools, `AGENTS.md`, skills, environment context, and sandbox permissions are assembled into the model input.

Decision:

- Keep setup inside Codex-native discovery paths.
- Use `AGENTS.md`, skills, sandbox policy, and OTel before inventing custom automation.
- Do not silently port Claude Code hook semantics into Codex.

Sources:

- https://openai.com/index/running-codex-safely/
- https://openai.com/index/unrolling-the-codex-agent-loop/
- https://github.com/openai/skills

### 2. Harness engineering now moves benchmark outcomes

LangChain reported a coding-agent improvement from 52.8 to 66.5 on Terminal Bench 2.0 by changing the harness while keeping the model fixed. Anthropic similarly frames long-running agent reliability as a harness problem involving context handoff, decomposed work, and evaluator patterns.

Decision:

- Treat this repo as a harness, not a prompt library.
- Keep hooks, rules, skills, command briefs, evals, and trace analysis together.
- Add benchmark and trace loops as first-class roadmap items.

Sources:

- https://www.langchain.com/blog/improving-deep-agents-with-harness-engineering
- https://www.langchain.com/blog/how-we-build-evals-for-deep-agents
- https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- https://www.anthropic.com/engineering/harness-design-long-running-apps

### 3. Agent evaluation should inspect behavior, not only final answers

Current eval guidance favors targeted evals, trace review, categories such as file operations/tool use/memory, and efficiency metrics. Agent-as-a-Judge research supports scalable evaluator agents, but it should complement deterministic checks and human oversight rather than replace them.

Decision:

- Keep deterministic tests first.
- Use `judge-agent.md` and `llm-judge.sh` for consolidation and subjective review.
- Add internal eval tasks with categories and step/tool ratios.

Sources:

- https://www.langchain.com/blog/how-we-build-evals-for-deep-agents
- https://arxiv.org/abs/2508.02994

### 4. Temporal memory is a better default than append-only notes

Zep's temporal knowledge graph work shows that dynamic, time-aware agent memory can improve long-context and cross-session retrieval while reducing latency in their benchmark setting. For this repo, the practical step is not to deploy a graph DB immediately; it is to standardize temporal metadata.

Decision:

- Add `memory-schema/` from Harness v6.
- Prefer `valid_from`, `valid_until`, `supersedes`, `confidence`, and `tags` for durable memory.
- Defer graph/vector indexing until memory volume justifies it.

Source:

- https://arxiv.org/abs/2501.13956

### 5. Security is now about agentic behavior and skill supply chain

OWASP Agentic Top 10 2026 frames autonomous agents as a distinct security surface. MCP-specific research identifies tool description poisoning, indirect prompt injection, parasitic tool chaining, and dynamic trust violations. Recent skill security research shows `SKILL.md` metadata and natural-language instructions can influence discovery, selection, and governance.

Decision:

- Treat third-party skills and hooks as supply-chain inputs.
- Keep provenance under `sources/`.
- Do not enable new hooks automatically.
- Require review for skill metadata, tool permissions, network use, and credentials.

Sources:

- https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/
- https://arxiv.org/abs/2603.18063
- https://arxiv.org/abs/2604.13849
- https://arxiv.org/abs/2605.11418
- https://arxiv.org/abs/2602.12430

### 6. Observability should align with OpenTelemetry GenAI

OpenTelemetry now includes semantic conventions for GenAI model, agent, framework, event, exception, metrics, and MCP-related spans. OpenAI also describes Codex telemetry for prompts, approvals, tool execution, MCP usage, and network decisions.

Decision:

- Keep `otel-trace-exporter.sh` as the bridge pattern.
- Add Codex OTel config only after choosing an endpoint.
- Prefer standard `gen_ai.*` and MCP attributes over bespoke logs where possible.

Sources:

- https://opentelemetry.io/docs/specs/semconv/gen-ai/
- https://openai.com/index/running-codex-safely/

### 7. Cost and token budgets should become explicit controls

Prompt caching, budget gates, and adaptive token allocation all point to the same operational reality: agent systems need cost-aware control loops. SelfBudgeter shows adaptive token allocation can compress reasoning length while preserving accuracy in benchmark settings.

Decision:

- Keep `budget-gate.sh`, `prompt-cache-monitor.sh`, and `model-router-v2.sh`.
- Run budget controls in `warn` before `block`.
- Add Codex-specific cost/usage extraction before automated blocking.

Sources:

- https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching
- https://arxiv.org/abs/2505.11274

### 8. Frontend agent work should use structured browser and design context

Playwright MCP uses accessibility snapshots, giving agents stable element references and structured page state. Chrome DevTools MCP adds console, network, screenshot, and performance trace access. Figma Dev Mode MCP brings selected frames, variables, components, and layout data into the agent workflow.

Decision:

- Use `playwright` first for local frontend inspection and interaction.
- Use `chrome-devtools` for console/network/performance debugging.
- Use `figma-desktop` when design context is needed and Figma Desktop has the MCP server enabled.
- Keep browser MCP sessions isolated from normal user profile data.

Sources:

- https://playwright.dev/mcp/introduction
- https://playwright.dev/mcp/snapshots
- https://github.com/ChromeDevTools/chrome-devtools-mcp
- https://developers.figma.com/docs/figma-mcp-server/
- https://developers.figma.com/docs/figma-mcp-server/local-server-installation/
- https://docs.sentry.io/product/sentry-mcp/
- https://www.prisma.io/docs/postgres/integrations/mcp-server
- https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem
- https://github.com/modelcontextprotocol/servers/tree/main/src/memory

### 9. Destructive shell commands need pre-tool policy

Official docs for Git, Docker, Kubernetes, Terraform, cloud CLIs, package registries, and databases all show command families that can delete durable state, rewrite history, or remove published artifacts. Agent workflows should convert these to dry-run/list/plan steps before execution.

Decision:

- Expand `hooks/dangerous-command-blocker.sh`.
- Add `docs/dangerous-command-guardrails.md`.
- Block broad deletes, destructive Git, DB/ORM reset, Docker volume deletion, K8s delete/drain, IaC destroy, cloud deletion, package unpublish, and disk/permission destruction.

Sources:

- https://git-scm.com/docs/git-clean
- https://git-scm.com/docs/git-reset
- https://developer.hashicorp.com/terraform/cli/commands/destroy
- https://docs.docker.com/engine/manage-resources/pruning/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_delete/
- https://awscli.amazonaws.com/v2/documentation/api/latest/reference/s3/rm.html
- https://docs.npmjs.com/unpublishing-packages-from-the-registry

### 10. Hermes-style curator loops should be reviewable files

Hermes Agent trends point toward persistent memory, skill curation, and autonomous self-improvement. In Codex, the safer translation is not an always-on daemon that rewrites its own operating system. The safer translation is a reviewable curator loop that writes reports and board items.

Decision:

- Add `docs/hermes-patterns-for-codex.md`.
- Add `scripts/codex-skill-curator.sh`.
- Add `scripts/codex-memory-audit.sh`.
- Add `hooks/skill-drift-checker.sh`.
- Add `progress/BOARD.md`.

Sources:

- https://github.com/NousResearch/hermes-agent
- https://hermes-agent.nousresearch.com/docs/
- https://newreleases.io/project/github/NousResearch/hermes-agent/release/v2026.4.30
- https://arxiv.org/abs/2605.13357

### 11. Native `/goal` should be paired with local durable packets

Codex `/goal` makes long-running objectives a first-class workflow. The local harness still adds value by creating branch/worktree isolation and durable `GOAL.md`, `PROMPT.md`, and `STATUS.md` files.

Decision:

- Enable `features.goals = true`.
- Update `commands/goal.md` and `skills/goal-runner/SKILL.md`.
- Extend `scripts/codex-goal.sh` with stop conditions and curator follow-up.
- Add `docs/goal-long-run-methodology.md`.

Sources:

- https://developers.openai.com/codex/cli/slash-commands
- https://openai.com/index/unrolling-the-codex-agent-loop/
- https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

## Gap Analysis

| Gap | Impact | Fix |
| --- | --- | --- |
| No Codex-native hook lifecycle | Cannot auto-run all Claude hooks safely | Patch scripts into manual commands, CI jobs, or Codex automations. |
| No internal eval benchmark | Score is architecture-based, not empirical | Add 20-task benchmark with expected tool paths and verification scripts. |
| OTel endpoint not configured | Trace exporter is not production telemetry yet | Add `settings/codex-otel.example.toml` after endpoint selection. |
| Skill supply-chain review is manual | Risk from untrusted `SKILL.md` and hook scripts | Add a skill trust checklist and metadata linter. |
| Memory schema is file-based | No retrieval ranking or stale fact detection at scale | Add index only after memory corpus grows. |
| GitHub/Sentry/Figma MCP need auth/runtime | Configured but not always usable immediately | Run OAuth/login flows and enable Figma Desktop MCP when needed. |
| Generic DB MCP needs scoped credentials | Global DB connection would be risky | Add Postgres/Supabase/Neon per project with dev/staging credentials only. |

## Final Recommendation

Use this repo as the single source of truth for Codex GUI/terminal setup. Install it through `setup_codex.sh`, restart Codex, and keep the v6 hooks disabled by default until each one is adapted, tested, and reviewed.
