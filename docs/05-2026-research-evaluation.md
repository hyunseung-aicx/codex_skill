# 2026 Research Evaluation

Date: 2026-05-14

## Overall Score

```text
7.2 / 10
```

## Summary

The current setup is aligned with 2026 trends in:

- skill-based agent customization
- context engineering
- MCP-based tool integration
- software engineering harness design
- human-in-the-loop agent workflows

It is weaker in:

- persistent observability
- formal skill evaluation
- structured long-term memory
- MCP security hardening

## Scorecard

| Area | Score | Notes |
| --- | ---: | --- |
| Skill Engineering | 8.5 | Rich skill stack, good FDE/PE fit |
| Harness Engineering | 8.5 | Local file/shell/browser/MCP loop is strong |
| Context Engineering | 8.0 | Jira/Confluence/GitHub/local repo context is well aligned |
| Human-in-the-loop | 8.0 | Good approval posture for high-risk actions |
| FDE/Product Workflow | 8.0 | Strong customer-to-implementation flow |
| Agent Evaluation | 4.0 | No internal benchmark yet |
| Observability | 4.5 | No trace/replay/cost/latency instrumentation yet |
| Long-term Memory | 5.0 | Session memory exists, structured memory does not |
| Security Governance | 5.5 | Good local restraint, needs MCP/tool hardening before automation |

## Research Signals

### 1. Agent Skills Are Useful but Need Evaluation

`SkillsBench` reports that curated skills can raise average pass rate, but effects vary by domain and some tasks regress. `SWE-Skills-Bench` focuses specifically on whether skills help real software engineering tasks.

Implication:

- Do not treat skills as magic prompts.
- Keep them focused.
- Build task-level evals.

### 2. Context Engineering Is Becoming a Discipline

Research on AI context files shows that projects are starting to maintain `AGENTS.md`-style files to encode build, test, architecture, and team conventions.

Implication:

- Each AICX repo should get an `AGENTS.md`.
- Context should be prescriptive, scoped, and version-controlled.

### 3. Harness and Agent-Computer Interface Matter

SWE-agent showed that the interface between agent and computer affects repository navigation, editing, and test execution. OpenAI's Codex materials also emphasize sandboxed execution, tests, logs, and AGENTS.md guidance.

Implication:

- Our local workspace + terminal + browser + MCP harness is directionally strong.
- Add persistent traces and standardized verification outputs.

### 4. MCP Is the Right Direction but Needs Security

MCP standardizes connection to external tools and context sources. The MCP tools spec recommends human-in-the-loop controls for tool invocation. Security research and OWASP MCP Top 10 warn about token exposure, scope creep, tool poisoning, command injection, and prompt injection.

Implication:

- Keep Atlassian/GitHub read-only by default.
- Split read and write tools.
- Add scoped credentials and tool call logging.

### 5. Agent Observability Is Rising

OpenTelemetry, Phoenix, LangSmith, and related tools are moving toward GenAI/agent trace conventions.

Implication:

- Add trace IDs to ticket processing.
- Record source reads, tool calls, decisions, generated plans, and tests.

## Recommendations

1. Create `AGENTS.md` per repo.
2. Add a local `context-pack` generator for each Jira ticket.
3. Add OpenTelemetry/Phoenix-style tracing to `personal-work-assistant`.
4. Build a 20-task internal skill benchmark.
5. Add read/write tool separation.
6. Add Slack notification only after read-only flow is stable.
7. Gate all write actions behind approval.

## Sources

- SWE-Skills-Bench: https://arxiv.org/abs/2603.15401
- SkillsBench: https://arxiv.org/abs/2602.12670
- Context Engineering for AI Agents: https://arxiv.org/abs/2510.21413
- SWE-agent: https://arxiv.org/abs/2405.15793
- Agentless: https://arxiv.org/abs/2407.01489
- SWE-bench Verified: https://www.swebench.com/verified.html
- SWE-Bench-CL: https://arxiv.org/abs/2507.00014
- MCP Specification: https://modelcontextprotocol.io/specification/2025-03-26/index
- MCP Tools: https://modelcontextprotocol.io/specification/2025-06-18/server/tools
- OpenAI Codex Agent Loop: https://openai.com/index/unrolling-the-codex-agent-loop/
- OpenAI Codex Intro: https://openai.com/index/introducing-codex/
- LangGraph: https://www.langchain.com/langgraph
- OpenTelemetry AI Agent Observability: https://opentelemetry.io/blog/2025/ai-agent-observability/
- OWASP MCP Top 10: https://owasp.org/www-project-mcp-top-10/
- OWASP LLM Top 10: https://owasp.org/www-project-top-10-for-large-language-model-applications
