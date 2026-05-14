# Executive Summary

## Problem

FDE/Product Engineer work is context-heavy. A single task may require:

- customer context from meetings and Confluence
- Jira tickets, epics, active sprints, assignees
- GitHub branches, commits, PRs
- local multi-repo code understanding
- architecture, API, RAG, chatbot, admin, infrastructure decisions

Traditional AI usage usually stops at prompt-response. That is not enough for real work.

## Proposal

Use Codex as a **personal engineering work harness**:

```text
customer/request
  -> product framing
  -> system design
  -> Jira/Confluence/GitHub context pack
  -> implementation plan
  -> code/test/doc execution
  -> PR/Jira/Confluence evidence
```

## Differentiator

This setup is not a prompt collection. It is a composable execution system:

- Skills define repeatable work procedures.
- MCP connects enterprise knowledge systems.
- Tool rules constrain unsafe execution.
- Local workspace access enables real verification.
- Human-in-the-loop gates high-risk actions.

## Best Demo Flow

1. Show the skill stack.
2. Query Jira/Confluence context for a customer project.
3. Show the local dashboard at `127.0.0.1:4173`.
4. Explain how a ticket becomes a context pack.
5. Show how the agent prepares branch/commit/PR plans without auto-merging.

## One Sentence

> The next step after prompt engineering is building an agent work harness: skills, tools, permissions, context, and verification loops designed for real enterprise workflows.
