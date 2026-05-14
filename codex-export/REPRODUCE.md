# Reproduce This Codex Setup

This document explains how to reproduce the shared parts of this Codex setup on another Mac.

Do not copy private auth, session, log, or cache files from `~/.codex`.

## 1. Review The Sanitized Config

Start with:

```text
codex-export/config/config.sanitized.toml
```

This file records:

- default model and reasoning effort
- enabled plugins
- configured MCP server names
- trusted project shape

Before using it on another machine, replace machine-specific paths such as `<HOME>` and make sure each trusted project path actually exists.

## 2. Install Or Restore Skills

The exported vendor skills are under:

```text
codex-export/vendor-skills/My_ClaudeCode_Skill/skills/
```

To reuse them, copy the desired skill directories into:

```text
~/.codex/skills/
```

System and plugin skills are managed by Codex and plugins, so they should usually be installed through Codex/plugin setup rather than copied manually.

## 3. Configure MCP Servers

This setup expects:

- Atlassian MCP for Jira/Confluence context
- Slack MCP for Slack context and notification workflows

Credentials must be configured locally on each machine. Do not commit MCP tokens or `.env` files.

## 4. Restore The Local Assistant App

The read-only Jira/Confluence/GitHub dashboard lives at:

```text
apps/personal-work-assistant/
```

Create a local `.env` from `.env.example`, then run:

```bash
node server.js
```

The default local URL is:

```text
http://127.0.0.1:4173
```

## 5. Security Checklist

Before pushing updates:

- confirm no `auth.json`, `history.jsonl`, `sessions/`, logs, cache, or `.env` files are staged
- run a token/path scan
- keep write/deploy/destructive tool actions behind approval
- keep Jira/Confluence/GitHub dashboards read-only until write workflows are reviewed

