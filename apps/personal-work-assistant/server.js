import http from "node:http";
import fs from "node:fs/promises";
import fsSync from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const publicDir = path.join(__dirname, "public");

loadDotEnv(path.join(__dirname, ".env"));

const config = {
  port: Number(process.env.PORT || 4173),
  atlassianSiteUrl: trimSlash(process.env.ATLASSIAN_SITE_URL || ""),
  atlassianEmail: process.env.ATLASSIAN_EMAIL || "",
  atlassianApiToken: process.env.ATLASSIAN_API_TOKEN || "",
  jiraProjectKey: process.env.JIRA_PROJECT_KEY || "AICC",
  confluenceSpaceKeys: parseList(process.env.CONFLUENCE_SPACE_KEYS || "AICC,TECH"),
  githubToken: process.env.GITHUB_TOKEN || "",
  githubOrg: process.env.GITHUB_ORG || "aicx-kr",
  githubUsername: process.env.GITHUB_USERNAME || "",
};

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || "/", `http://${req.headers.host}`);

    if (url.pathname.startsWith("/api/")) {
      await handleApi(req, res, url);
      return;
    }

    await serveStatic(res, url.pathname);
  } catch (error) {
    sendJson(res, 500, {
      error: "internal_error",
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

server.listen(config.port, "127.0.0.1", () => {
  console.log(`Personal Work Assistant: http://127.0.0.1:${config.port}`);
});

async function handleApi(req, res, url) {
  if (req.method !== "GET") {
    sendJson(res, 405, { error: "method_not_allowed" });
    return;
  }

  if (url.pathname === "/api/config") {
    sendJson(res, 200, {
      jiraProjectKey: config.jiraProjectKey,
      confluenceSpaceKeys: config.confluenceSpaceKeys,
      githubOrg: config.githubOrg,
      githubUsername: config.githubUsername,
      connections: {
        atlassian: Boolean(config.atlassianSiteUrl && config.atlassianEmail && config.atlassianApiToken),
        github: Boolean(config.githubToken),
      },
    });
    return;
  }

  if (url.pathname === "/api/work-context") {
    const data = await buildWorkContext();
    sendJson(res, 200, data);
    return;
  }

  if (url.pathname === "/api/jira/my-issues") {
    const mode = url.searchParams.get("mode") || "active";
    const issues = await fetchMyJiraIssues(mode);
    sendJson(res, 200, { issues });
    return;
  }

  if (url.pathname.startsWith("/api/jira/issue/")) {
    const issueKey = decodeURIComponent(url.pathname.replace("/api/jira/issue/", ""));
    const issue = await fetchJiraIssue(issueKey);
    sendJson(res, 200, { issue });
    return;
  }

  if (url.pathname === "/api/confluence/search") {
    const query = url.searchParams.get("q") || "";
    const results = await searchConfluence(query);
    sendJson(res, 200, { results });
    return;
  }

  if (url.pathname === "/api/github/search") {
    const query = url.searchParams.get("q") || "";
    const results = await searchGitHub(query);
    sendJson(res, 200, { results });
    return;
  }

  sendJson(res, 404, { error: "not_found" });
}

async function buildWorkContext() {
  const [activeIssues, assignedIssues, githubAssigned] = await Promise.all([
    fetchMyJiraIssues("active").catch(toConnectionError),
    fetchMyJiraIssues("assigned").catch(toConnectionError),
    searchGitHub(config.githubUsername ? `org:${config.githubOrg} is:pr is:open involves:${config.githubUsername}` : "").catch(toConnectionError),
  ]);

  const issues = Array.isArray(activeIssues) ? activeIssues : [];
  const contextTargets = issues.slice(0, 6);
  const related = await Promise.all(
    contextTargets.map(async (issue) => {
      const key = issue.key;
      const summary = issue.fields?.summary || "";
      const compactQuery = `${key} ${summary}`.slice(0, 120);
      const [docs, prs] = await Promise.all([
        searchConfluence(compactQuery).catch(() => []),
        searchGitHub(`org:${config.githubOrg} is:pr ${key}`).catch(() => []),
      ]);
      return { key, docs: docs.slice(0, 5), prs: prs.slice(0, 5) };
    }),
  );

  return {
    generatedAt: new Date().toISOString(),
    activeIssues,
    assignedIssues,
    githubAssigned,
    related,
    checklist: buildChecklist(issues, related),
  };
}

function buildChecklist(issues, related) {
  return issues.map((issue) => {
    const fields = issue.fields || {};
    const links = related.find((item) => item.key === issue.key);
    const sprintNames = getSprintNames(fields);
    const missing = [];

    if (!fields.assignee?.displayName) missing.push("담당자 없음");
    if (!fields.description) missing.push("설명 없음");
    if (sprintNames.length === 0) missing.push("활성 스프린트 없음");
    if (!links || links.docs.length === 0) missing.push("관련 Confluence 미확인");
    if (!links || links.prs.length === 0) missing.push("연결 PR 미확인");

    return {
      key: issue.key,
      summary: fields.summary,
      status: fields.status?.name || "",
      priority: fields.priority?.name || "",
      sprintNames,
      missing,
    };
  });
}

async function fetchMyJiraIssues(mode) {
  requireAtlassian();

  const base = `project = ${config.jiraProjectKey} AND assignee = currentUser() AND statusCategory != Done`;
  const jql =
    mode === "active"
      ? `${base} AND sprint in openSprints() ORDER BY priority DESC, updated DESC`
      : `${base} ORDER BY updated DESC`;

  const payload = {
    jql,
    maxResults: 50,
    fields: [
      "summary",
      "status",
      "assignee",
      "priority",
      "issuetype",
      "parent",
      "duedate",
      "description",
      "updated",
      "customfield_10020",
    ],
  };

  const response = await atlassianFetch("/rest/api/3/search/jql", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });

  return response.issues || [];
}

async function fetchJiraIssue(issueKey) {
  requireAtlassian();
  const fields = [
    "summary",
    "description",
    "status",
    "assignee",
    "reporter",
    "priority",
    "issuetype",
    "parent",
    "duedate",
    "updated",
    "comment",
    "issuelinks",
    "customfield_10020",
  ].join(",");
  return atlassianFetch(`/rest/api/3/issue/${encodeURIComponent(issueKey)}?fields=${fields}`);
}

async function searchConfluence(query) {
  requireAtlassian();
  if (!query.trim()) return [];

  const spaceClause =
    config.confluenceSpaceKeys.length > 0
      ? ` AND space in (${config.confluenceSpaceKeys.map((space) => `"${escapeCql(space)}"`).join(",")})`
      : "";
  const cql = `type = page AND text ~ "${escapeCql(query)}"${spaceClause} ORDER BY lastmodified DESC`;
  const apiPath = `/wiki/rest/api/content/search?limit=10&expand=space,version&cql=${encodeURIComponent(cql)}`;
  const response = await atlassianFetch(apiPath);

  return (response.results || []).map((item) => ({
    id: item.id,
    title: item.title,
    space: item.space?.name || item.space?.key || "",
    updatedAt: item.version?.when || "",
    url: `${config.atlassianSiteUrl}/wiki${item._links?.webui || ""}`,
  }));
}

async function searchGitHub(query) {
  if (!config.githubToken || !query.trim()) return [];

  const response = await fetch(`https://api.github.com/search/issues?q=${encodeURIComponent(query)}&per_page=20`, {
    headers: {
      authorization: `Bearer ${config.githubToken}`,
      accept: "application/vnd.github+json",
      "user-agent": "personal-work-assistant",
      "x-github-api-version": "2022-11-28",
    },
  });

  if (!response.ok) {
    throw new Error(`GitHub API failed: ${response.status} ${await response.text()}`);
  }

  const body = await response.json();
  return (body.items || []).map((item) => ({
    id: item.id,
    title: item.title,
    state: item.state,
    url: item.html_url,
    repository: item.repository_url?.split("/").slice(-1)[0] || "",
    updatedAt: item.updated_at,
    author: item.user?.login || "",
  }));
}

async function atlassianFetch(apiPath, options = {}) {
  const response = await fetch(`${config.atlassianSiteUrl}${apiPath}`, {
    ...options,
    headers: {
      authorization: `Basic ${Buffer.from(`${config.atlassianEmail}:${config.atlassianApiToken}`).toString("base64")}`,
      accept: "application/json",
      ...(options.headers || {}),
    },
  });

  if (!response.ok) {
    throw new Error(`Atlassian API failed: ${response.status} ${await response.text()}`);
  }

  return response.json();
}

async function serveStatic(res, requestPath) {
  const safePath = requestPath === "/" ? "/index.html" : requestPath;
  const resolved = path.normalize(path.join(publicDir, safePath));

  if (!resolved.startsWith(publicDir)) {
    sendText(res, 403, "Forbidden");
    return;
  }

  try {
    const body = await fs.readFile(resolved);
    res.writeHead(200, { "content-type": contentType(resolved) });
    res.end(body);
  } catch {
    sendText(res, 404, "Not Found");
  }
}

function loadDotEnv(filePath) {
  try {
    const text = fsSync.readFileSync(filePath, "utf8");
    for (const line of text.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const index = trimmed.indexOf("=");
      if (index === -1) continue;
      const key = trimmed.slice(0, index).trim();
      const value = trimmed.slice(index + 1).trim().replace(/^["']|["']$/g, "");
      if (!process.env[key]) process.env[key] = value;
    }
  } catch {
    // .env is optional.
  }
}

function requireAtlassian() {
  if (!config.atlassianSiteUrl || !config.atlassianEmail || !config.atlassianApiToken) {
    throw new Error("Atlassian connection is not configured. Fill ATLASSIAN_SITE_URL, ATLASSIAN_EMAIL, ATLASSIAN_API_TOKEN.");
  }
}

function getSprintNames(fields) {
  return (fields.customfield_10020 || []).map((sprint) => sprint.name).filter(Boolean);
}

function toConnectionError(error) {
  return {
    error: "connection_error",
    message: error instanceof Error ? error.message : String(error),
  };
}

function sendJson(res, status, body) {
  res.writeHead(status, { "content-type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(body, null, 2));
}

function sendText(res, status, body) {
  res.writeHead(status, { "content-type": "text/plain; charset=utf-8" });
  res.end(body);
}

function contentType(filePath) {
  if (filePath.endsWith(".html")) return "text/html; charset=utf-8";
  if (filePath.endsWith(".css")) return "text/css; charset=utf-8";
  if (filePath.endsWith(".js")) return "text/javascript; charset=utf-8";
  return "application/octet-stream";
}

function parseList(value) {
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function trimSlash(value) {
  return value.replace(/\/+$/, "");
}

function escapeCql(value) {
  return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}
