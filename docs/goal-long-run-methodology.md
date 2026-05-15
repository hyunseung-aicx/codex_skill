# Codex `/goal` Long-Run Methodology

Date: 2026-05-15

## Current Status

Codex `/goal` is an experimental long-running objective workflow exposed through slash commands. It requires:

```toml
[features]
goals = true
```

Core commands:

```text
/goal <objective>
/goal pause
/goal resume
/goal clear
```

Our local harness keeps the official `/goal` workflow and adds durable goal packets through `codex-goal`.

## Why `/goal` Matters for Ralphthon-Style Work

Ralphthon work is usually not a single prompt. It is a long loop:

1. understand the product/developer goal
2. inspect code and docs
3. create a plan
4. implement one slice
5. verify
6. update durable status
7. continue after context shifts, lunch, meetings, or background work

Research and industry case studies suggest long-running agents perform better when the harness supplies:

- durable memory and progress files
- branch/worktree isolation
- decomposed subtasks
- tool and permission guardrails
- deterministic verification loops
- evaluator or judge checks
- resumable handoff prompts

Sources:

- https://developers.openai.com/codex/cli/slash-commands
- https://openai.com/index/unrolling-the-codex-agent-loop/
- https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- https://www.anthropic.com/engineering/harness-design-long-running-apps
- https://www.langchain.com/blog/improving-deep-agents-with-harness-engineering
- https://www.langchain.com/blog/how-we-build-evals-for-deep-agents

## Recommended Flow

### 1. Create a Goal Packet

```bash
codex-goal "upgrade the dashboard search UX and add tests" \
  --hours 4 \
  --branch codex/goal-dashboard-search \
  --verify "npm test" \
  --worktree
```

This creates:

```text
.codex-goals/<goal-id>/GOAL.md
.codex-goals/<goal-id>/PROMPT.md
.codex-goals/<goal-id>/STATUS.md
```

### 2. Start `/goal`

Paste the generated prompt into Codex GUI/terminal, or use:

```text
/goal upgrade the dashboard search UX and add tests
```

Then point Codex to the generated `GOAL.md` and `STATUS.md`.

### 3. Work In Checkpoints

Each checkpoint should include:

- one concrete slice
- files changed
- tests/build/lint run
- status update
- next exact action

Target cadence:

```text
30-45 min inspect/plan
45-90 min implementation slice
10-20 min verification
5 min STATUS.md update
repeat
```

### 4. Use Stop Conditions

Stop and ask if any of these appear:

- destructive command or production data change
- secret/credential/auth change
- paid external service operation
- ambiguous product decision
- migration touching non-dev DB
- test failure that implies a requirement conflict
- diff growing beyond the goal contract

### 5. End With Continuation

Before stopping, update `STATUS.md` with:

- summary
- changed files
- commands run and results
- risks
- exact continuation prompt

## Long-Run Prompt Template

```text
/goal

Objective:
<single concrete outcome>

Timebox:
<N hours>

Branch/worktree:
Use codex/goal-<slug>. Keep changes isolated.

Durable state:
Update .codex-goals/<goal-id>/STATUS.md after every checkpoint.

Operating loop:
Inspect -> plan -> implement one slice -> verify -> status update -> continue.

Verification:
<targeted test/build/lint/e2e commands>

Stop conditions:
Ask before destructive commands, production data, secrets, paid services, broad rewrites, or ambiguous decisions.

Final report:
Changed files, verification result, unresolved risks, next continuation prompt.
```

## Scoring A Goal Session

Use this after a goal finishes:

| Dimension | 0 | 1 | 2 |
| --- | --- | --- | --- |
| Objective clarity | vague | mostly clear | concrete and testable |
| Isolation | same branch | branch | worktree/branch |
| Progress durability | chat only | partial status | current `STATUS.md` |
| Verification | none | partial | targeted + broad where needed |
| Safety | risky actions | manual caution | guardrails and stop conditions |
| Handoff | missing | summary only | exact continuation prompt |

Score:

```text
0-6: weak
7-9: usable
10-12: Ralphthon-ready
```

## After-Goal Curator Loop

After a multi-hour goal:

```bash
scripts/codex-skill-curator.sh
scripts/codex-memory-audit.sh
```

Then create follow-up items in:

```text
progress/BOARD.md
```

This mirrors Hermes-style self-improvement while keeping changes reviewable.
