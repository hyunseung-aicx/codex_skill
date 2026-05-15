# Unified Integration Report

Date: 2026-05-14

## Goal

Create one Codex-first setup from two inputs:

1. `My_ClaudeCode_Skill` currently installed on this Mac.
2. `hyunseung-aicx/claude_skill` Harness v6.

The result is not a raw Claude Code clone. It is a Codex-native skillpack that keeps Claude-oriented hooks and agents as portable references unless they are explicitly adapted.

## Input Comparison

| Area | Existing installed skillpack | New Harness v6 | Integrated decision |
| --- | --- | --- | --- |
| Codex skills | 40 `SKILL.md` folders already visible to Codex GUI/CLI | No Codex `skills/` directory | Keep all 40 and add `codex-harness-v6`. |
| Slash commands | 34 command briefs | None | Keep command briefs as Codex reference workflows. |
| Agents | 24 role briefs | `judge-agent.md` plus README | Merge judge agent into `agents/`. |
| Rules | 16 rule packs | None | Keep rules; use them selectively. |
| Hooks | 36 operational hooks | 10 v6 harness hooks | Merge scripts, but classify as reference/adaptable, not automatic Codex hooks. |
| Memory | Progress schema and learning hooks | Temporal memory schema | Add `memory-schema/` as the preferred durable-memory pattern. |
| Settings | Claude local settings and Codex setup scripts | Claude `settings.example.json` | Preserve v6 settings as Claude example; add Codex guidance in docs. |
| Install | `setup_codex.sh`, doctor, update, uninstall | macOS Claude guide only | Reuse Codex setup scripts and expand doctor expectations. |
| Research score | 2026-04 score | 2026-05 score | Replace with 2026-05-15 scorecard. |

## Final Repository Shape

```text
codex_skill/
├── README.md
├── setup_codex.sh
├── uninstall_codex.sh
├── skills/
│   ├── ... 40 existing skills
│   └── codex-harness-v6/
├── commands/
├── agents/
│   └── judge-agent.md
├── rules/
├── hooks/
│   ├── existing deterministic hooks
│   └── v6 budget/router/dedup/judge/otel/cache hooks
├── memory-schema/
├── settings/
├── docs/
│   ├── unified-integration-report.md
│   └── 2026-05-15-research-scorecard.md
└── sources/
    ├── legacy-skillpack/
    └── claude-harness-v6/
```

## What Is Active After Install

Active in Codex:

- `skills/**/SKILL.md` discovery.
- `codex-harness-v6` as the unified governance skill.
- `codex-claude-skillpack` as the Claude command/rule adapter.
- `commands/`, `agents/`, `rules/` as reference resources.
- `codex-skillpack-doctor`, `codex-skillpack-update`, and `codex-goal` maintenance commands.

Available but not automatically active:

- Claude Code `hooks/*.sh`.
- `settings/settings.example.json`.
- v6 `llm-judge.sh` external API call.
- Benchmark runner.
- OTel exporter until Codex trace wiring is configured.

## Hook Classification

| Hook | Class | Rationale |
| --- | --- | --- |
| `dangerous-command-blocker.sh`, `secret-detector.sh`, `pre-commit-security.sh` | portable | Deterministic checks; useful as manual/CI helpers. |
| `budget-gate.sh` | codex-adaptable | Useful, but currently reads Claude transcript fields and writes to `.claude`. |
| `tool-hash-dedup.sh` | codex-adaptable | Needs Codex tool-call event export or wrapper. |
| `model-router-v2.sh`, `tool-selector.sh` | advisory | Good routing heuristics; actual Codex model/tool selection remains user/tool controlled. |
| `llm-judge.sh` | codex-adaptable | Valuable judge pattern; needs explicit API key and controlled invocation. |
| `otel-trace-exporter.sh` | codex-adaptable | Must align with Codex OTel log schema. |
| `prompt-cache-monitor.sh` | reference | Claude prompt-cache fields do not directly imply Codex cache semantics. |
| `bench-runner.sh` | codex-adaptable | Needs a task directory and scheduler/automation. |

## Design Decisions

1. Keep one repo, not two linked vendor imports.
2. Prefer Codex skills over giant global instructions.
3. Keep Claude command and hook materials as resources, not implicit authority.
4. Add security notes because skill files are executable operational text in practice.
5. Use temporal memory frontmatter for durable facts and decisions.
6. Score the setup against current agent-harness research, not only local completeness.

## Remaining Work

- Add a Codex-specific OTel config example once the target endpoint is known.
- Add a 20-task internal benchmark under `benchmarks/`.
- Patch selected hooks to support `CODEX_HOME` and project-local trace directories.
- Add CI that runs `scripts/codex-skillpack-doctor.sh`.
- Add a skill trust policy for third-party skill updates.
