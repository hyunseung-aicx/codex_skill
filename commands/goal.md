# /goal

Durable long-running development workflow for Codex GUI and terminal.

## Purpose

Use `/goal` when the user wants Codex to keep developing during lunch, meetings, after work, or any long timebox from about 1 hour up to a full-day background session. The workflow must split work by Git branch/worktree, preserve progress in files, and make it easy to move between GUI supervision and terminal execution.

## Workflow

1. Clarify the objective only if the goal is unsafe or too ambiguous to start.
2. Prefer a dedicated branch named `codex/goal-<short-slug>`.
3. Prefer a Codex app worktree for unattended GUI/background work, because it isolates changes from the local checkout.
4. Use local terminal only for foreground commands, app-specific dev servers, or manual verification that needs the user's local environment.
5. Keep a durable status file under `.codex-goals/<goal-id>/STATUS.md`.
6. Run the smallest reliable verification loop repeatedly: targeted tests first, then build/lint/e2e when the blast radius justifies it.
7. Stop before destructive actions, secrets, paid external services, production data changes, or ambiguous product decisions.

## GUI <-> Terminal Handoff

- GUI to terminal: use the Codex app worktree path, open its terminal, and continue from the branch/worktree listed in `STATUS.md`.
- Terminal to GUI: paste `.codex-goals/<goal-id>/PROMPT.md` into a new Codex app thread and select Worktree mode based on the goal branch.
- If a branch is checked out in a worktree, do not check out the same branch in local terminal at the same time. Use Codex Handoff or a separate branch.

## Terminal Helper

When shell access is available, create the packet with:

```bash
codex-goal "implement the feature" --hours 3 --branch codex/goal-feature --verify "npm test" --worktree
```

Then use the generated `PROMPT.md` as the GUI prompt.

## Long-Run Prompt Template

```text
/goal

Objective:
<specific outcome>

Timebox:
<1-15 hours>

Branch/worktree:
Use codex/goal-<slug>. Keep changes isolated.

Verification:
<test/build/lint commands or auto-detect>

Report:
Update .codex-goals/<goal-id>/STATUS.md after every checkpoint. Before stopping, list changed files, tests run, unresolved issues, and the next exact continuation prompt.
```
