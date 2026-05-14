# Roadmap

## Phase 0: Current

- Codex skills available
- Atlassian MCP available
- local repo inspection and editing
- browser verification
- read-only personal dashboard MVP

## Phase 1: Standardize Context

- Add `AGENTS.md` to each major repo.
- Create repo-specific runbooks:
  - setup
  - test
  - branch target
  - deployment cautions
  - architecture summary

## Phase 2: Ticket Context Pack

Generate a Markdown file per ticket:

```text
context-packs/AICC-123.md
```

Content:

- issue summary
- parent epic
- sprint
- assignee
- related Confluence docs
- related PRs
- likely repos
- open questions
- implementation plan
- test plan

## Phase 3: Observability

Add traces:

- ticket detected
- Jira fetched
- Confluence searched
- GitHub searched
- repo scanned
- plan generated
- files changed
- tests run

Candidate tools:

- OpenTelemetry
- Phoenix
- LangSmith
- Langfuse

## Phase 4: Slack Read-Only Assistant

Trigger:

- assigned issue
- sprint added
- status changed
- mention in comment

Output:

- Slack DM summary
- dashboard link
- missing-context checklist

## Phase 5: Approval-Based Execution

Actions behind approval:

- create branch
- edit files
- run tests
- draft PR
- comment on Jira

Never automatic without approval:

- merge
- production deploy
- DB write
- destructive git commands

## Phase 6: Internal Benchmark

Create evaluation tasks from real AICC work:

- Jira triage
- Confluence retrieval
- repo identification
- branch/PR drafting
- architecture explanation
- missing requirement detection

Track:

- accuracy
- time saved
- missing context
- hallucinated links
- reviewer corrections
