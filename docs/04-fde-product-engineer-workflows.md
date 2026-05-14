# FDE / Product Engineer Workflows

## Role Framing

FDE/Product Engineer sits between:

- customer problem
- product design
- engineering implementation
- operations and delivery

The agent should help transform ambiguity into executable work.

## Workflow 1: New Customer Requirement

```text
customer request
  -> summarize JTBD and pain points
  -> find related Confluence docs
  -> locate Jira epic or create draft structure
  -> map affected systems
  -> create API/data/infrastructure questions
  -> propose phased plan
```

Recommended skills:

- `product-planner`
- `architecture-design`
- `api-spec-generator`
- `rag-2.0`
- `agentic-workflows`

## Workflow 2: Assigned Jira Ticket

```text
Jira ticket assigned
  -> fetch issue, parent, sprint, comments
  -> fetch related Confluence pages
  -> search GitHub branches/PRs by issue key
  -> identify likely repo
  -> create context pack
  -> propose branch name and implementation plan
```

Output:

```text
Ticket: AICC-123
Parent/Epic:
Sprint:
Status:
Likely repos:
Related docs:
Open questions:
Implementation plan:
Test plan:
Branch:
PR title:
```

## Workflow 3: Customer AI System Design

```text
customer domain
  -> current support workflow
  -> channel/API constraints
  -> RAG/data source design
  -> handoff policy
  -> admin/ops requirements
  -> safety/evaluation plan
```

Good for:

- 오늘의집
- 보살핌
- MRT partner chatbot
- B2B callbot/chatbot deployments

## Workflow 4: Delivery Evidence

```text
code change
  -> tests/build
  -> screenshots/API checks
  -> PR body
  -> Jira comment
  -> Confluence update if architecture changed
```

## Personal Dashboard MVP

`apps/personal-work-assistant` implements the first read-only version:

- my active sprint Jira tickets
- assigned unresolved tickets
- related Confluence search
- related GitHub PR search
- missing-context checklist

It should stay read-only until authentication, audit, and approval flow are hardened.
