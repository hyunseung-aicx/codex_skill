# Codex Global Setup Export

This directory is a sanitized export of the Codex setup currently recognized on this Mac.

Source location:

```text
~/.codex
```

Export date:

```text
2026-05-14
```

## Included

| Item | Exported |
| --- | --- |
| sanitized `config.toml` | yes |
| enabled marketplace/plugin summary | yes |
| MCP server summary | yes |
| system skill index | yes |
| plugin skill index | yes |
| vendor-imported skill files | yes |
| local personal assistant app | yes, under `apps/personal-work-assistant` |

## Excluded

The following are intentionally excluded:

- `~/.codex/auth.json`
- `~/.codex/history.jsonl`
- `~/.codex/session_index.jsonl`
- `~/.codex/sessions/`
- `~/.codex/log/`
- `~/.codex/*.sqlite`
- `~/.codex/cache/`
- `~/.codex/models_cache.json`
- `~/.codex/installation_id`
- `~/.codex/shell_snapshots/`
- any `.env` file

These may contain session data, auth state, local history, logs, cache, machine identity, or sensitive operational details.

## Current Shape

```text
Codex global setup
  -> model: gpt-5.5
  -> reasoning: high
  -> trusted project: $HOME/Desktop/aicx-repos
  -> MCP:
     - Atlassian remote MCP
     - Slack local MCP command
  -> Plugins:
     - Browser
     - Documents
     - Presentations
     - Spreadsheets
  -> Skills:
     - 5 system skills
     - 4 plugin skills
     - 40 vendor-imported skills
```

## Why This Matters

This setup is a local agent workbench:

- skills define repeatable work procedures
- MCP connects enterprise systems
- plugins expose browser/document/spreadsheet/presentation capabilities
- sandbox and approval rules control risk
- local workspace trust allows multi-repo engineering work

It is not just prompt engineering. It is a skill and harness layer around Codex.
