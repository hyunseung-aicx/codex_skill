---
name: fde-product-engineer
description: Use when converting customer requirements into product scope, system design, implementation plan, Jira/Confluence artifacts, and delivery evidence.
---

# FDE / Product Engineer Skill

## Goal

Turn ambiguous customer or business requests into executable engineering work.

## Workflow

1. Identify customer, channel, user, and business goal.
2. Search Jira for existing epics/tickets.
3. Search Confluence for roadmap, meeting notes, architecture, API docs.
4. Map affected systems and repos.
5. Separate:
   - product requirements
   - API requirements
   - data requirements
   - infrastructure requirements
   - operations/QA requirements
6. Draft implementation phases.
7. Produce a ticket-ready checklist.

## Output

```markdown
## Context

## Customer Goal

## Current System Assumption

## Affected Repos

## API/Data/Infra Questions

## Proposed Phases

## Jira Breakdown

## Risks

## Next Actions
```

## Rules

- Prefer current company docs over generic advice.
- State assumptions explicitly.
- Do not invent API contracts.
- If a requirement affects customer data or production systems, mark it as high-risk.
- Recommend human approval before write/deploy actions.
