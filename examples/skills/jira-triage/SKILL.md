---
name: jira-triage
description: Use when a Jira issue is assigned or updated and needs context collection, prioritization, related docs, likely repo, and next-step planning.
---

# Jira Triage Skill

## Goal

Create a complete work packet for a Jira issue.

## Inputs

- Jira issue key
- assignee
- sprint
- parent epic
- current status
- description/comments

## Workflow

1. Fetch Jira issue.
2. Fetch parent/epic.
3. Identify sprint and due date.
4. Search Confluence by issue key, customer name, and summary terms.
5. Search GitHub PRs/branches/commits by issue key.
6. Identify likely repos.
7. Detect missing information.
8. Draft branch name, implementation plan, and test plan.

## Missing Information Checklist

- no assignee
- no sprint
- no acceptance criteria
- no related Confluence
- no affected repo
- no test plan
- ambiguous customer/system boundary

## Output

```markdown
## Issue

## Priority

## Related Context

## Likely Repos

## Missing Info

## Suggested Branch

## Implementation Plan

## Test Plan

## Suggested Jira Comment
```
