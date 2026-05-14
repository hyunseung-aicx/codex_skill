#!/usr/bin/env bash
# shellcheck shell=bash
# PreToolUse: block high-risk shell commands before they mutate local files,
# repositories, databases, cloud resources, containers, or infrastructure.
#
# Input contract: JSON from a Claude Code/Codex-style tool hook:
#   { "tool_name": "Bash", "tool_input": { "command": "..." } }
#
# This script is intentionally conservative. Use dry-runs, targeted commands,
# backups, and explicit human approval for destructive operations.

set -uo pipefail

INPUT=$(cat 2>/dev/null || printf '{}')

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

block() {
  local reason="$1"
  jq -cn --arg reason "$reason" '{decision:"block", reason:$reason}'
  exit 0
}

block_if() {
  local pattern="$1"
  local reason="$2"
  if printf '%s' "$COMMAND" | grep -qiE "$pattern"; then
    block "$reason"
  fi
}

# ---------------------------------------------------------------------------
# Filesystem and project-source destruction
# ---------------------------------------------------------------------------

block_if '\brm\b[[:space:]]+[^;&|]*-[A-Za-z]*r[A-Za-z]*f|\\brm\\b[[:space:]]+[^;&|]*-[A-Za-z]*f[A-Za-z]*r' \
  "[SAFETY:filesystem] Recursive force deletion detected. Use a narrower target, dry-run/list first, and ask for explicit approval."

block_if '\brm\b.*(--no-preserve-root|[[:space:]]/([[:space:]]|$)|[[:space:]]/\*|[[:space:]]~/?\*|[[:space:]]\.\.?([[:space:]]|$)|[[:space:]]\*)' \
  "[SAFETY:filesystem] Broad rm target detected (root/home/dot/wildcard). This can destroy important local files."

block_if '\b(find|fd)\b.*[[:space:]]-delete\b' \
  "[SAFETY:filesystem] find/fd -delete detected. List matched files first and get explicit approval before deletion."

block_if '\bxargs\b.*\brm\b|\\bparallel\\b.*\\brm\\b' \
  "[SAFETY:filesystem] Bulk deletion through xargs/parallel detected. Review the generated target list first."

block_if '\b(shred|srm|wipe)\b|\bdd\b.*[[:space:]]of=/dev/|\b(mkfs|newfs|fdisk|parted|gparted)\b|\bdiskutil\b.*(erase|partition|apfs[[:space:]]+delete)' \
  "[SAFETY:disk] Disk wipe/format/partition command detected. This can irreversibly destroy data."

block_if '\b(chmod|chown|chgrp)\b[^\n;&|]*-[A-Za-z]*R[A-Za-z]*[^\n;&|]*(/|\.|~|[[:space:]]\*)|\\bchmod\\b[^\n;&|]*(777|a\\+rw|ugo\\+rw)' \
  "[SAFETY:permissions] Recursive/broad permission or ownership change detected. This can break security boundaries."

block_if '\b(rm|rmdir|trash|unlink)\b[^\n;&|]*(\.git|\.github|\.env|\.env\.[A-Za-z0-9_-]+|src|app|pages|components|lib|server|client|db|database|migrations|prisma|schema\.prisma|package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb|Dockerfile|docker-compose\.ya?ml|compose\.ya?ml|k8s|kubernetes|charts|terraform\.tfstate|\.tfvars)' \
  "[SAFETY:project] Deletion of project-critical files/directories detected. Confirm intent and backup/state first."

# ---------------------------------------------------------------------------
# Git history, worktree, and tag destruction
# ---------------------------------------------------------------------------

if printf '%s' "$COMMAND" | grep -qiE '\bgit[[:space:]]+push\b.*--force([[:space:]]|$)' && \
   ! printf '%s' "$COMMAND" | grep -qiE '\bgit[[:space:]]+push\b.*--force-with-lease'; then
  block "[SAFETY:git] git push --force detected. This can overwrite remote history. Use --force-with-lease only after explicit approval."
fi

block_if '\bgit[[:space:]]+push\b.*[[:space:]]-f([[:space:]]|$)' \
  "[SAFETY:git] git push -f detected. This can overwrite remote history. Use --force-with-lease only after explicit approval."

block_if '\bgit[[:space:]]+reset\b[^\n;&|]*--hard|\bgit[[:space:]]+checkout\b[^\n;&|]*[[:space:]]-f([[:space:]]|$)|\bgit[[:space:]]+restore\b[^\n;&|]*(--staged[^\n;&|]*--worktree|--worktree[^\n;&|]*--staged)' \
  "[SAFETY:git] Destructive git worktree reset detected. Preserve or inspect local changes before proceeding."

block_if '\bgit[[:space:]]+clean\b[^\n;&|]*(-[A-Za-z]*f|--force)' \
  "[SAFETY:git] git clean force detected. Run git clean -n first; -x/-d can delete ignored env/build files."

block_if '\bgit[[:space:]]+(branch|tag)[[:space:]]+-D|\bgit[[:space:]]+tag[[:space:]]+-d|\bgit[[:space:]]+update-ref[[:space:]]+-d|\bgit[[:space:]]+reflog[[:space:]]+expire\b.*--expire=now|\bgit[[:space:]]+gc\b.*--prune=now' \
  "[SAFETY:git] Git ref/tag/reflog deletion detected. This can remove recovery paths."

block_if '\bgit[[:space:]]+(filter-branch|filter-repo)\b|\bbfg\b' \
  "[SAFETY:git] Git history rewrite tool detected. Require a backup branch and explicit approval."

# ---------------------------------------------------------------------------
# Database and ORM destructive operations
# ---------------------------------------------------------------------------

block_if '\bdrop[[:space:]]+(database|schema|table)\b|\btruncate[[:space:]]+(table[[:space:]]+)?[A-Za-z0-9_."`]+' \
  "[SAFETY:database] DROP/TRUNCATE detected. This is destructive and often irreversible."

block_if '\bdelete[[:space:]]+from[[:space:]]+[A-Za-z0-9_."`]+[[:space:]]*;?[[:space:]]*$|\bupdate[[:space:]]+[A-Za-z0-9_."`]+[[:space:]]+set[[:space:]][^;&|]*;?[[:space:]]*$' \
  "[SAFETY:database] SQL DELETE/UPDATE without an obvious WHERE clause detected."

block_if '\b(dropdb|dropuser)\b|\b(redis-cli|valkey-cli)\b.*flush(all|db)\b|\b(db\.dropDatabase|dropDatabase\(|\.drop\(\))' \
  "[SAFETY:database] Database/user/drop/flush command detected."

block_if '\b(prisma[[:space:]]+migrate[[:space:]]+reset|prisma[[:space:]]+db[[:space:]]+push\b.*--force-reset|supabase[[:space:]]+db[[:space:]]+reset|rails[[:space:]]+db:(drop|reset)|rake[[:space:]]+db:(drop|reset)|sequelize[[:space:]]+db:migrate:undo:all|typeorm[[:space:]]+migration:revert)\b' \
  "[SAFETY:orm] ORM/database reset command detected. Confirm this is a disposable development database."

# ---------------------------------------------------------------------------
# Containers and local volumes
# ---------------------------------------------------------------------------

block_if '\bdocker[[:space:]]+system[[:space:]]+prune\b.*(-a|--all|--volumes|-f|--force)|\bdocker[[:space:]]+volume[[:space:]]+(rm|prune)\b|\bdocker[[:space:]]+image[[:space:]]+prune\b.*(-a|--all)|\bdocker[[:space:]]+(compose|container)?[[:space:]]*rm\b.*(-v|--volumes)|\bdocker[[:space:]]+compose\b.*down\b.*(-v|--volumes|--rmi)' \
  "[SAFETY:docker] Docker prune/volume removal detected. Volumes may contain databases and local state."

# ---------------------------------------------------------------------------
# Kubernetes, Helm, and cluster operations
# ---------------------------------------------------------------------------

block_if '\bkubectl[[:space:]]+delete\b|\bkubectl[[:space:]]+replace\b.*--force|\bkubectl[[:space:]]+drain\b|\bkubectl[[:space:]]+scale\b.*--replicas=0|\bkubectl[[:space:]]+patch[[:space:]]+namespace\b.*finalizers' \
  "[SAFETY:kubernetes] Kubernetes destructive operation detected. Verify context, namespace, selector, and rollback plan."

block_if '\bhelm[[:space:]]+(uninstall|delete)\b|\bhelmfile[[:space:]]+destroy\b' \
  "[SAFETY:kubernetes] Helm release deletion detected. Verify cluster context and namespace first."

# ---------------------------------------------------------------------------
# Infrastructure-as-code and cloud resources
# ---------------------------------------------------------------------------

block_if '\b(terraform|tofu)[[:space:]]+destroy\b|\b(terraform|tofu)[[:space:]]+apply\b.*-(destroy|auto-approve)|\b(terraform|tofu)[[:space:]]+state[[:space:]]+(rm|mv)\b|\bpulumi[[:space:]]+destroy\b|\bcdk[[:space:]]+destroy\b|\bserverless[[:space:]]+remove\b' \
  "[SAFETY:infra] Infrastructure destroy/state mutation detected. Require plan output, workspace/account check, and approval."

if printf '%s' "$COMMAND" | grep -qiE '\baws[[:space:]]+s3[[:space:]]+rm[[:space:]]+s3://[^\n;&|]*--recursive' && \
   ! printf '%s' "$COMMAND" | grep -qiE '(^|[[:space:]])--dryrun([[:space:]]|$)'; then
  block "[SAFETY:cloud] AWS S3 recursive deletion detected. Use --dryrun first and verify account, region, bucket, and prefix."
fi

block_if '\baws[[:space:]]+s3[[:space:]]+rb[^\n;&|]*--force|\baws[[:space:]]+(cloudformation[[:space:]]+delete-stack|eks[[:space:]]+delete-cluster|rds[[:space:]]+delete-db-instance|dynamodb[[:space:]]+delete-table|ec2[[:space:]]+(terminate-instances|delete-volume)|iam[[:space:]]+delete-)' \
  "[SAFETY:cloud] AWS destructive resource deletion detected. Verify account, region, resource IDs, and backup."

block_if '\bgcloud\b[^\n;&|]*(delete|remove)\b|\bgcloud\b[^\n;&|]*--delete-disks[[:space:]]+all|\bgcloud\b[^\n;&|]*--quiet[^\n;&|]*(delete|remove)' \
  "[SAFETY:cloud] GCP destructive command detected. Verify project, zone/region, and prompt-suppression flags."

block_if '\baz[[:space:]]+(group|resource|vm|aks|sql|storage)[[:space:]][^\n;&|]*\b(delete|remove|purge)\b|\baz[[:space:]]+storage[[:space:]]+blob[[:space:]]+delete-batch\b' \
  "[SAFETY:cloud] Azure destructive command detected. Verify subscription, resource group, and backup."

# ---------------------------------------------------------------------------
# Package registry and release-supply-chain operations
# ---------------------------------------------------------------------------

block_if '\b(npm|pnpm|yarn)\b[^\n;&|]*\bunpublish\b|\bnpm[[:space:]]+dist-tag[[:space:]]+rm\b|\bgh[[:space:]]+release[[:space:]]+delete\b|\bgit[[:space:]]+push\b[^\n;&|]*:[[:space:]]*refs/tags/' \
  "[SAFETY:release] Package/release/tag deletion detected. This can break consumers or remove published artifacts."

exit 0
