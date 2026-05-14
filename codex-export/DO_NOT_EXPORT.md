# Do Not Export

Do not commit or publish the following from `~/.codex`.

## Authentication and Identity

```text
auth.json
installation_id
```

## Session and History

```text
history.jsonl
session_index.jsonl
sessions/
```

## Logs and Databases

```text
log/
logs_*.sqlite*
state_*.sqlite*
sqlite/
```

## Cache and Runtime State

```text
cache/
models_cache.json
shell_snapshots/
ambient-suggestions/
.tmp/
tmp/
```

## Environment Files

```text
.env
*.env
```

## Why

These files can include:

- auth state
- local interaction history
- prompt/session contents
- tool logs
- machine identifiers
- cached model/runtime metadata
- shell command traces
- potentially sensitive workplace context

Only sanitized configuration and reusable skill definitions should be exported.
