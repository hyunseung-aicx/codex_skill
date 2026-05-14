const state = {
  config: null,
  context: null,
};

const elements = {
  refreshButton: document.querySelector("#refreshButton"),
  connectionBadge: document.querySelector("#connectionBadge"),
  activeCount: document.querySelector("#activeCount"),
  assignedCount: document.querySelector("#assignedCount"),
  pullRequestCount: document.querySelector("#pullRequestCount"),
  riskCount: document.querySelector("#riskCount"),
  ticketList: document.querySelector("#ticketList"),
  checklist: document.querySelector("#checklist"),
  githubList: document.querySelector("#githubList"),
  contextList: document.querySelector("#contextList"),
  issueDialog: document.querySelector("#issueDialog"),
  dialogTitle: document.querySelector("#dialogTitle"),
  dialogBody: document.querySelector("#dialogBody"),
  closeDialog: document.querySelector("#closeDialog"),
};

elements.refreshButton.addEventListener("click", loadDashboard);
elements.closeDialog.addEventListener("click", () => elements.issueDialog.close());

await loadDashboard();

async function loadDashboard() {
  setLoading();
  try {
    const [config, context] = await Promise.all([fetchJson("/api/config"), fetchJson("/api/work-context")]);
    state.config = config;
    state.context = context;
    render();
  } catch (error) {
    renderError(error);
  }
}

function render() {
  const { config, context } = state;
  const activeIssues = asArray(context.activeIssues);
  const assignedIssues = asArray(context.assignedIssues);
  const githubAssigned = asArray(context.githubAssigned);
  const checklist = asArray(context.checklist);

  const risks = checklist.filter((item) => item.missing.length > 0);
  elements.activeCount.textContent = activeIssues.length;
  elements.assignedCount.textContent = assignedIssues.length;
  elements.pullRequestCount.textContent = githubAssigned.length;
  elements.riskCount.textContent = risks.length;

  const connected = config.connections.atlassian && config.connections.github;
  elements.connectionBadge.textContent = connected
    ? "Jira / Confluence / GitHub 연결됨"
    : "일부 연결값 필요";
  elements.connectionBadge.className = connected ? "badge ok" : "badge warn";

  renderTickets(activeIssues);
  renderChecklist(checklist);
  renderGitHub(githubAssigned);
  renderContext(context.related || []);
}

function renderTickets(issues) {
  if (!issues.length) {
    elements.ticketList.innerHTML = `<div class="empty">활성 스프린트 내 담당 티켓이 없거나 Atlassian 연결값이 없습니다.</div>`;
    return;
  }

  elements.ticketList.innerHTML = issues.map(ticketTemplate).join("");
  for (const item of elements.ticketList.querySelectorAll("[data-issue-key]")) {
    item.addEventListener("click", () => openIssue(item.dataset.issueKey));
  }
}

function ticketTemplate(issue) {
  const fields = issue.fields || {};
  const parent = fields.parent ? `${fields.parent.key} · ${escapeHtml(fields.parent.fields?.summary || "")}` : "Parent 없음";
  const sprints = sprintNames(fields).join(", ") || "스프린트 없음";
  return `
    <div class="ticket" data-issue-key="${escapeHtml(issue.key)}">
      <div class="ticket-title">
        <strong>${escapeHtml(issue.key)} · ${escapeHtml(fields.summary || "")}</strong>
        <span class="tag">${escapeHtml(fields.status?.name || "-")}</span>
      </div>
      <div class="meta">
        <span class="tag">${escapeHtml(fields.priority?.name || "Priority 없음")}</span>
        <span class="tag">${escapeHtml(fields.assignee?.displayName || "담당자 없음")}</span>
        <span class="tag">${escapeHtml(sprints)}</span>
      </div>
      <p>${escapeHtml(parent)}</p>
    </div>
  `;
}

function renderChecklist(items) {
  if (!items.length) {
    elements.checklist.innerHTML = `<div class="empty">점검할 티켓이 없습니다.</div>`;
    return;
  }

  elements.checklist.innerHTML = items
    .map((item) => {
      const missing = item.missing.length ? item.missing.join(", ") : "누락 없음";
      return `
        <div class="check-item">
          <strong>${escapeHtml(item.key)} · ${escapeHtml(item.summary || "")}</strong>
          <div class="missing">${escapeHtml(missing)}</div>
        </div>
      `;
    })
    .join("");
}

function renderGitHub(items) {
  if (!items.length) {
    elements.githubList.innerHTML = `<div class="empty">열린 PR이 없거나 GitHub 연결값이 없습니다.</div>`;
    return;
  }

  elements.githubList.innerHTML = items
    .map(
      (item) => `
        <div class="link-item">
          <a href="${escapeHtml(item.url)}" target="_blank" rel="noreferrer">${escapeHtml(item.title)}</a>
          <p>${escapeHtml(item.repository)} · ${escapeHtml(item.author)} · ${formatDate(item.updatedAt)}</p>
        </div>
      `,
    )
    .join("");
}

function renderContext(items) {
  if (!items.length) {
    elements.contextList.innerHTML = `<div class="empty">티켓별 관련 문서/PR 맥락이 없습니다.</div>`;
    return;
  }

  elements.contextList.innerHTML = items
    .map((item) => {
      const docs = item.docs.length
        ? item.docs
            .map((doc) => `<li><a href="${escapeHtml(doc.url)}" target="_blank" rel="noreferrer">${escapeHtml(doc.title)}</a></li>`)
            .join("")
        : "<li>관련 Confluence 문서 없음</li>";
      const prs = item.prs.length
        ? item.prs
            .map((pr) => `<li><a href="${escapeHtml(pr.url)}" target="_blank" rel="noreferrer">${escapeHtml(pr.title)}</a></li>`)
            .join("")
        : "<li>관련 PR 없음</li>";
      return `
        <div class="context-item">
          <strong>${escapeHtml(item.key)}</strong>
          <p>Confluence</p>
          <ul>${docs}</ul>
          <p>GitHub</p>
          <ul>${prs}</ul>
        </div>
      `;
    })
    .join("");
}

async function openIssue(issueKey) {
  elements.dialogTitle.textContent = issueKey;
  elements.dialogBody.textContent = "불러오는 중...";
  elements.issueDialog.showModal();
  try {
    const { issue } = await fetchJson(`/api/jira/issue/${encodeURIComponent(issueKey)}`);
    elements.dialogTitle.textContent = `${issue.key} · ${issue.fields?.summary || ""}`;
    elements.dialogBody.textContent = JSON.stringify(issue, null, 2);
  } catch (error) {
    elements.dialogBody.textContent = error.message;
  }
}

function setLoading() {
  elements.connectionBadge.textContent = "불러오는 중";
  elements.connectionBadge.className = "badge";
  elements.ticketList.innerHTML = `<div class="empty">Jira, Confluence, GitHub 맥락을 불러오는 중입니다.</div>`;
  elements.checklist.innerHTML = "";
  elements.githubList.innerHTML = "";
  elements.contextList.innerHTML = "";
}

function renderError(error) {
  elements.connectionBadge.textContent = "로드 실패";
  elements.connectionBadge.className = "badge warn";
  elements.ticketList.innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
}

async function fetchJson(url) {
  const response = await fetch(url);
  const body = await response.json();
  if (!response.ok) {
    throw new Error(body.message || body.error || `Request failed: ${response.status}`);
  }
  return body;
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function sprintNames(fields) {
  return (fields.customfield_10020 || []).map((sprint) => sprint.name).filter(Boolean);
}

function formatDate(value) {
  if (!value) return "";
  return new Intl.DateTimeFormat("ko-KR", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
