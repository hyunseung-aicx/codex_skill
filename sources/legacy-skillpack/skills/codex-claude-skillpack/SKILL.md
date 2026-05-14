---
name: codex-claude-skillpack
description: Claude Code skillpack을 Codex CLI/GUI에서 사용할 때 적용하는 호환 어댑터입니다. 사용자가 "/goal", "/plan", "/tdd", "/verify", "/code-review", "/modern-frontend", "/build-fix", "/debug", "/orchestrate", "/multi-agent", "/checkpoint", "/learn" 같은 Claude 스타일 slash command를 Codex에서 요청하거나, 이 저장소의 rules/agents/commands/hooks를 Codex 작업 방식으로 해석해 달라고 할 때 사용합니다.
---

# Codex Adapter for the Claude Skillpack

This skill lets Codex use the repository's Claude-oriented material without pretending the two runtimes are identical.

## Resource Locations

The installer links resources here:

- Skills: `$HOME/.codex/skills/<skill-name>/SKILL.md`
- Claude commands: `$HOME/.codex/claude-skillpack/commands/*.md`
- Claude agents: `$HOME/.codex/claude-skillpack/agents/*.md`
- Claude rules: `$HOME/.codex/claude-skillpack/rules/*.md`
- Claude hook scripts: `$HOME/.codex/claude-skillpack/hooks/*.sh`
- Original global Claude guide: `$HOME/.codex/claude-skillpack/CLAUDE.md`
- Standards-based skill mirror: `$HOME/.agents/skills/<skill-name>/SKILL.md`
- Maintenance commands: `$HOME/.codex/bin/codex-skillpack-doctor` and `$HOME/.codex/bin/codex-skillpack-update`
- Goal runner command: `$HOME/.codex/bin/codex-goal`

If `CODEX_HOME` is set, use `$CODEX_HOME` instead of `$HOME/.codex`.

## Operating Rules

1. Codex system/developer instructions always take precedence over this skillpack.
2. Treat `commands/`, `agents/`, `rules/`, and `hooks/` as reference material, not automatically executable Codex configuration.
3. For Claude slash commands, read the matching file in `commands/` and perform the intent using native Codex tools and constraints.
4. For Claude agents, read the matching file in `agents/` as a role brief. Use native Codex subagents only when the current Codex instructions and the user request permit delegation.
5. For rules, load only the relevant rule files for the current task. Do not import every rule into context by default.
6. For hooks, inspect scripts as deterministic checklists or runnable helpers. Do not wire them into Codex automatically unless the user explicitly asks for that integration.
7. For installation or freshness questions, read `references/operations.md` and run the doctor script when local shell access is available.

## Slash Command Routing

When the user types a Claude-style command, map it to the corresponding Markdown file:

- `/plan` -> `commands/plan.md`
- `/goal` -> `commands/goal.md`
- `/spec` -> `commands/spec.md`
- `/tdd` -> `commands/tdd.md`
- `/verify` -> `commands/verify.md`
- `/code-review` -> `commands/code-review.md`
- `/debug` -> `commands/debug.md`
- `/build-fix` -> `commands/build-fix.md`
- `/refactor-clean` -> `commands/refactor-clean.md`
- `/modern-frontend` -> `commands/modern-frontend.md`
- `/frontend-codemap` -> `commands/frontend-codemap.md`
- `/update-codemaps` -> `commands/update-codemaps.md`
- `/update-docs` -> `commands/update-docs.md`
- `/test-coverage` -> `commands/test-coverage.md`
- `/e2e` -> `commands/e2e.md`
- `/go-review` -> `commands/go-review.md`
- `/go-build` -> `commands/go-build.md`
- `/go-test` -> `commands/go-test.md`
- `/rust` -> `commands/rust.md`
- `/eval` -> `commands/eval.md`
- `/orchestrate` -> `commands/orchestrate.md`
- `/multi-agent` -> `commands/multi-agent.md`
- `/checkpoint` -> `commands/checkpoint.md`
- `/handoff` -> `commands/handoff.md`
- `/learn` -> `commands/learn.md`
- `/token-analysis` -> `commands/token-analysis.md`
- `/tool-registry` -> `commands/tool-registry.md`
- `/define-dod` -> `commands/define-dod.md`
- `/setup-pm` -> `commands/setup-pm.md`
- `/skill-create` -> `commands/skill-create.md`
- `/evolve` -> `commands/evolve.md`
- `/instinct-status` -> `commands/instinct-status.md`
- `/instinct-export` -> `commands/instinct-export.md`
- `/instinct-import` -> `commands/instinct-import.md`

## Recommended Use

- If a normal Codex skill already matches the task, use that skill directly.
- If the user invokes a Claude command, load the command file first, then any rule or agent file it names.
- If a Claude instruction conflicts with Codex safety, filesystem, git, browser, or delegation rules, follow Codex and briefly adapt the workflow.
- Preserve the user's Korean/English working style from the request.

## Maintenance

For setup audits, updates, and scoring, read `references/operations.md`, then prefer these small ACI-style commands:

```bash
codex-skillpack-doctor
codex-skillpack-update
```
