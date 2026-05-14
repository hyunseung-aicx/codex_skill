# Skill Engineering

## Definition

A skill is a task-specific procedural package that tells the agent how to behave for a class of work.

It should contain:

- trigger conditions
- workflow steps
- required checks
- output format
- references or scripts
- safety constraints

## Why It Matters

Recent skill benchmarks suggest that curated skills can improve task success, but poorly scoped skills can reduce performance. The implication is clear: skills should be small, focused, testable, and tied to real workflows.

## Our Skill Stack

| Work Type | Skill Examples | Role Value |
| --- | --- | --- |
| Customer/product framing | `product-planner` | Converts vague customer needs into scope, roadmap, tradeoffs |
| Architecture | `architecture-design` | Produces diagrams, ADRs, API/data-flow decisions |
| Chatbot/LLM systems | `chatbot-designer`, `llm-app-planner` | Selects RAG vs agent vs workflow patterns |
| RAG | `rag-2.0` | Designs retrieval, chunking, evals, grounding |
| Agent workflow | `agentic-workflows` | Designs LangGraph-style routing and human approvals |
| API contract | `api-design`, `api-spec-generator` | Creates customer/backend/frontend contracts |
| Code quality | `clean-code`, `backend-api`, `react-component` | Keeps implementation maintainable |
| Evaluation | `agent-evaluator`, `industry-persona-qa` | Checks whether AI output is usable in domain context |
| Delivery | `git-workflow`, `documentation-gen` | Connects Jira, PR, Confluence, release evidence |

## Skill Design Rules

1. Keep skills focused.
2. Avoid broad "do everything" instructions.
3. Include verification steps.
4. Encode team conventions.
5. Keep generated actions reversible.
6. Prefer read-only analysis before write actions.
7. Add examples for branch names, commit messages, PR format, Jira comments.

## Anti-Patterns

- skills that duplicate each other
- skills that encourage automatic production changes
- skills without acceptance criteria
- skills that hide uncertainty
- skills that load too much irrelevant context

## Evaluation Plan

Create a small benchmark for our work:

```text
Task 1: summarize an AICC Jira ticket into implementation steps
Task 2: identify related Confluence pages
Task 3: choose the likely repo and files
Task 4: draft a branch name and PR body
Task 5: detect missing acceptance criteria
```

Measure:

- correctness
- missing-context rate
- hallucinated-source rate
- time saved
- reviewer correction count
