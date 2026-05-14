# Harness Engineering

## Definition

Harness engineering is the design of the runtime environment in which an AI agent can safely and repeatably perform work.

For Codex, the harness includes:

- filesystem access
- terminal execution
- browser verification
- MCP tools
- permission boundaries
- skill routing
- local environment context
- test and verification loops

## Current Harness

```text
Codex
  -> local workspace
  -> shell commands
  -> file patching
  -> browser/local server checks
  -> Atlassian MCP
  -> web research when needed
  -> human approval for elevated actions
```

## Why It Matters

Software engineering agents are not just models. Research around SWE-agent and Codex-style loops shows that agent-computer interface design affects real task performance.

Good harnesses let agents:

- inspect code
- search efficiently
- edit files safely
- run tests
- observe failures
- iterate with evidence

Poor harnesses produce confident but unverifiable answers.

## Recommended Harness Layers

### 1. Context Layer

- `AGENTS.md`
- README
- Jira issue
- Confluence docs
- GitHub PR history
- local file tree

### 2. Tool Layer

- read tools: `rg`, `sed`, `git log`, Jira search, Confluence search
- write tools: `apply_patch`, Jira comments, PR creation
- verify tools: test commands, build commands, browser screenshots, API calls

### 3. Permission Layer

- read-only default
- approval for port binding, network, writes outside workspace
- explicit approval for destructive or production actions

### 4. Trace Layer

Future target:

```text
trace_id
  -> user_request
  -> selected_skill
  -> sources_read
  -> tools_called
  -> files_changed
  -> tests_run
  -> final_decision
```

### 5. Output Layer

Every non-trivial run should produce:

- what changed
- why it changed
- what was verified
- what remains risky
- links to Jira/Confluence/PR where relevant

## Current Gap

The harness exists, but trace and replay are not yet persistent. Add OpenTelemetry/Phoenix/LangSmith-style traces next.
