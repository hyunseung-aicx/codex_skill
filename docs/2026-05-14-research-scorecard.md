# 2026-05-14 Research Scorecard

Date: 2026-05-14

## Verdict

```text
Unified codex_skill score: 8.9 / 10
Grade: A-
```

The setup is strong enough to be used as a daily Codex skill/harness layer. It is not yet A+ because v6 hooks are merged as reference/adaptable assets rather than fully wired Codex event hooks, and because internal eval/benchmark data is not yet present.

## Scorecard

| Area | Score | Evidence-based rationale |
| --- | ---: | --- |
| Skill portability and discovery | 9.3 | Uses Codex-discoverable `skills/**/SKILL.md`; mirrors the Agent Skills folder model. |
| Harness engineering | 9.1 | Combines skills, command briefs, rules, hooks, progress, and maintenance scripts. |
| Tool/MCP governance | 8.6 | Strong approval posture and MCP awareness; needs stricter read/write credential separation. |
| Evaluation and judge quality | 8.4 | Adds judge agent, LLM judge hook, verification hooks; needs internal task benchmark. |
| Observability and replay | 8.2 | Adds trace hooks and OTel exporter references; Codex-native OTel config still needs endpoint wiring. |
| Memory and context hygiene | 8.8 | Adds temporal memory schema and scoped context rules; no vector/graph index yet. |
| Security and supply-chain controls | 8.7 | Includes dangerous command, secret, dependency, MCP, and skill supply-chain guidance. |
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

## Gap Analysis

| Gap | Impact | Fix |
| --- | --- | --- |
| No Codex-native hook lifecycle | Cannot auto-run Claude hooks safely | Patch scripts into manual commands, CI jobs, or Codex automations. |
| No internal eval benchmark | Score is architecture-based, not empirical | Add 20-task benchmark with expected tool paths and verification scripts. |
| OTel endpoint not configured | Trace exporter is not production telemetry yet | Add `settings/codex-otel.example.toml` after endpoint selection. |
| Skill supply-chain review is manual | Risk from untrusted `SKILL.md` and hook scripts | Add a skill trust checklist and metadata linter. |
| Memory schema is file-based | No retrieval ranking or stale fact detection at scale | Add index only after memory corpus grows. |

## Final Recommendation

Use this repo as the single source of truth for Codex GUI/terminal setup. Install it through `setup_codex.sh`, restart Codex, and keep the v6 hooks disabled by default until each one is adapted, tested, and reviewed.
