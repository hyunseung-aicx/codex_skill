---
name: goal-runner
description: Long-running Codex development workflow for "/goal" requests, lunch/meeting/after-hours autonomous coding, branch/worktree isolation, GUI-to-terminal handoff, Codex automations, and durable progress tracking. Use when the user wants Codex to keep developing for 1-15 hours, split work across git branches, resume later, or coordinate Codex GUI with terminal sessions.
---

# Goal Runner

Use this skill for durable, reviewable long-running development.

## Core Pattern

1. Convert the user request into a concrete objective, timebox, branch name, verification command, and stop conditions.
2. Put work on a dedicated branch or Codex app worktree.
3. Track progress in `.codex-goals/<goal-id>/STATUS.md` so context loss does not erase the plan.
4. Work in checkpoints: inspect, plan, implement one slice, verify, log status, continue.
5. Before stopping, leave a continuation prompt and exact verification status.

## Evidence-Informed Defaults

- Use worktrees for unattended or GUI background work because they isolate changes and allow handoff between Local and Worktree.
- Use small CLI helpers for repeatable operations. Agent-computer-interface research shows software agents perform better when common actions are exposed as clear, purpose-built commands with structured feedback.
- Use evaluation loops for long tasks: each iteration should have a score or concrete verification command.
- Use skills for repeatable workflows so Codex does not need to rediscover the process each time.

## Terminal Helper

Prefer the helper when creating a new goal:

```bash
codex-goal "your objective" --hours 3 --branch codex/goal-short-name --verify "npm test" --worktree
```

This creates a goal packet with `GOAL.md`, `PROMPT.md`, and `STATUS.md`.

## GUI Flow

1. Create the goal packet from terminal or ask Codex GUI to follow `/goal`.
2. In Codex app, choose Worktree for background work.
3. Use Automations for repeated wake-ups or recurring checks. For active follow-up loops, use thread automations; for independent runs, use standalone project automations.
4. Use Handoff when moving the same thread between Local and Worktree.

## Safety Gates

Stop and ask before:

- destructive commands or force pushes
- production data changes
- paid external service usage
- secrets, credentials, or auth changes without clear instructions
- broad rewrites that exceed the goal contract

## Completion Format

Report:

- branch/worktree used
- changed files
- verification commands and results
- unresolved risks
- next continuation prompt
