# MCP Developer Stack

Date: 2026-05-14

## Current Score Impact

This MCP layer raises the Codex repo setup from:

```text
8.9 / 10 -> 9.3 / 10
Grade: A-
```

The setup is not A+ yet because GitHub/Sentry and Figma require user-side authentication/runtime state, DB connectors need project-specific credentials, and observability/evals are still not fully automated.

## Installed Global MCP Servers

Configured in `~/.codex/config.toml`:

| Server | Type | Purpose | Status |
| --- | --- | --- | --- |
| `atlassian` | remote HTTP | Jira/Confluence context and actions | enabled |
| `slack` | local stdio | Slack integration through local wrapper | enabled |
| `openaiDeveloperDocs` | remote HTTP | Official OpenAI/Codex/API documentation lookup | enabled |
| `playwright` | local stdio via `npx` | Frontend page interaction through accessibility snapshots, screenshots, tests | enabled |
| `chrome-devtools` | local stdio via `npx` | Live Chrome inspection: console, network, screenshots, performance traces | enabled |
| `figma-desktop` | local HTTP | Figma Dev Mode MCP context from selected designs/components | enabled, requires Figma Desktop server |
| `context7` | local stdio via `npx` | Current library/framework docs and examples | enabled |
| `github` | remote HTTP | GitHub official MCP server | enabled, authentication may be required |
| `filesystem` | local stdio via `npx` | Workspace-scoped filesystem MCP for MCP-native resource/tool workflows | enabled, limited to `/Users/sinhyeonseung/Desktop/aicx-repos` |
| `memory` | local stdio via `npx` | Persistent entity/relation memory graph MCP | enabled |
| `sentry` | remote HTTP | Sentry issue/error context and debugging | enabled, OAuth still needs user completion |
| `prisma-local` | local stdio via `npx` | Prisma local project/database workflow MCP | enabled, useful inside Prisma projects |

## Why These MCPs

### Frontend Fixes Without Screenshot Guesswork

`playwright` is the default frontend inspection tool. It uses accessibility snapshots: structured trees of roles, text, and stable element refs. This is more reliable than guessing coordinates from screenshots and is ideal for:

- finding buttons/forms/labels in local apps
- reproducing user UI issues
- clicking through flows
- capturing screenshots only when visual layout matters
- turning findings into Playwright tests

Sources:

- https://playwright.dev/mcp/introduction
- https://playwright.dev/mcp/snapshots
- https://playwright.dev/mcp/capabilities

### Browser Debugging and Performance

`chrome-devtools` complements Playwright. Use it when the problem is not just "what is on screen" but browser internals:

- console errors
- network requests
- source-mapped stack traces
- performance traces
- screenshots from a live Chrome instance

The server is configured with `--isolated=true` and `--no-usage-statistics` to avoid exposing the normal browser profile and opt out of usage stats.

Source:

- https://github.com/ChromeDevTools/chrome-devtools-mcp

### Design-to-Code Context

`figma-desktop` lets Codex pull design variables, components, layout data, and selected frames from Figma Dev Mode. It requires Figma Desktop:

1. Open Figma Desktop.
2. Open the design file.
3. Switch to Dev Mode.
4. Enable the desktop MCP server.
5. Keep `http://127.0.0.1:3845/mcp` running.

Source:

- https://developers.figma.com/docs/figma-mcp-server/
- https://developers.figma.com/docs/figma-mcp-server/local-server-installation/

### Current Docs While Coding

`context7` and `openaiDeveloperDocs` reduce stale-doc mistakes:

- `openaiDeveloperDocs`: use for OpenAI API, Agents SDK, ChatGPT Apps, and Codex questions.
- `context7`: use for React, Next.js, Prisma, Supabase, Tailwind, Playwright, and other framework/library docs.

Sources:

- https://developers.openai.com/learn/docs-mcp
- https://upstash.com/blog/context7-mcp

### GitHub Context

`github` is configured against GitHub's official remote MCP endpoint. It may require OAuth/PAT login before tools are usable.

Source:

- https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp-in-your-ide/set-up-the-github-mcp-server

### Filesystem and Memory

`filesystem` exists for MCP-native clients and workflows that need resource/tool discovery. Codex itself already has native file tools, so this server is scoped to the workspace root instead of the full home directory.

`memory` provides entity/relation memory. Use it for durable project or user preferences only when the user explicitly wants facts remembered. Do not store secrets, credentials, private customer data, or transient guesses.

Sources:

- https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem
- https://github.com/modelcontextprotocol/servers/tree/main/src/memory

### DB and ORM

`prisma-local` is installed because many frontend/backend projects use Prisma. It should be used in project context, not as a global production DB bridge.

Generic DB MCPs such as Postgres, Supabase, Neon, or Prisma Postgres require credentials/OAuth and must be added per project. Do not put production `DATABASE_URL` values in global Codex config.

Sources:

- https://www.prisma.io/docs/postgres/integrations/mcp-server
- https://supabase.com/docs/guides/getting-started/mcp
- https://neon.com/docs/ai/neon-mcp-server

### Sentry

`sentry` is configured against Sentry's official MCP endpoint. It started an OAuth flow during setup; authorization must be completed by the user before it can inspect organizations/projects/issues.

Use Sentry MCP when:

- a frontend/backend error has a Sentry issue ID
- stack traces, release versions, or suspect commits are needed
- a production bug needs correlation with recent deploys

Source:

- https://docs.sentry.io/product/sentry-mcp/

## Usage Policy

Use MCP servers in this order:

1. Local repo files and tests first.
2. `playwright` for frontend page state and interaction.
3. `chrome-devtools` for console/network/performance.
4. `figma-desktop` only when a Figma design or selection is relevant.
5. `context7` for framework/library docs.
6. `openaiDeveloperDocs` for OpenAI/Codex docs.
7. `github` for issue/PR/repo context after auth is configured.
8. `sentry` for production error context after OAuth is configured.
9. `filesystem` only when an MCP-native file resource is specifically useful; otherwise prefer Codex native file tools.
10. `memory` only for explicit durable facts.
11. `prisma-local` only inside project directories with Prisma schema/config.

Security defaults:

- Do not use normal Chrome profile data for MCP debugging.
- Prefer isolated browser contexts.
- Do not feed production credentials or private user data into browser MCP sessions.
- Treat MCP tools as privileged integrations and keep write operations explicit.

## Current Config Fragment

```toml
[mcp_servers.openaiDeveloperDocs]
url = "https://developers.openai.com/mcp"

[mcp_servers.playwright]
command = "npx"
args = ["-y", "@playwright/mcp@latest", "--browser=chrome", "--isolated", "--caps=testing,storage,vision,network"]

[mcp_servers.chrome-devtools]
command = "npx"
args = ["-y", "chrome-devtools-mcp@latest", "--isolated=true", "--no-usage-statistics"]

[mcp_servers.figma-desktop]
url = "http://127.0.0.1:3845/mcp"

[mcp_servers.context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp@latest"]

[mcp_servers.github]
url = "https://api.githubcopilot.com/mcp/"

[mcp_servers.filesystem]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-filesystem", "/Users/sinhyeonseung/Desktop/aicx-repos"]

[mcp_servers.memory]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-memory"]

[mcp_servers.sentry]
url = "https://mcp.sentry.dev/mcp"

[mcp_servers.prisma-local]
command = "npx"
args = ["-y", "prisma", "mcp"]
```

## Verification

Run:

```bash
codex mcp list
```

Expected enabled servers:

```text
atlassian
slack
openaiDeveloperDocs
playwright
chrome-devtools
figma-desktop
context7
github
filesystem
memory
sentry
prisma-local
```

Auth/runtime follow-up:

```bash
codex mcp login sentry
```

For Figma, start Figma Desktop Dev Mode MCP first. For project DBs, add a scoped MCP server in the project with dev/staging credentials only.
