# Security

globs: ['**/*.ts', '**/*.js', '**/*.py', '**/*.go', '**/*.rs', '**/Dockerfile', '**/*.yaml', '**/*.yml']

## Pre-Commit Checklist
- [ ] No hardcoded secrets (use env vars, .env in .gitignore)
- [ ] All user inputs validated and sanitized
- [ ] SQL: parameterized queries only
- [ ] XSS: sanitized HTML output
- [ ] CSRF protection enabled
- [ ] Auth/authz on all non-public endpoints
- [ ] Rate limiting on all endpoints
- [ ] Error messages don't leak internals

## OWASP API Top Risks
- **BOLA**: Always check object ownership before returning data
- **BFLA**: Admin endpoints require role check middleware
- **Mass Assignment**: Whitelist allowed fields, never pass req.body directly
- **Data Exposure**: Use DTOs, return only necessary fields
- **Rate Limiting**: Global + strict limits on auth endpoints

## Response Protocol
1. STOP on security issue discovery
2. Use **security-reviewer** agent
3. Fix CRITICAL before continuing
4. Rotate exposed secrets immediately

## Dangerous Command Guardrails

Codex must not run destructive shell commands automatically. Use
`hooks/dangerous-command-blocker.sh` as the canonical pre-tool policy and
`docs/dangerous-command-guardrails.md` as the rationale/catalog.

Blocked categories include:

- recursive/broad deletion: `rm -rf`, `find -delete`, `xargs rm`, wildcard/root/home/dot deletes
- project-critical deletion: `.git`, `.env`, `src`, `app`, `db`, `migrations`, lockfiles, Docker/K8s/Terraform files
- Git destruction: `git reset --hard`, `git clean -fdx`, unsafe force push, reflog/tag/ref deletion, history rewrite
- database/ORM destruction: `DROP`, `TRUNCATE`, `DELETE` without `WHERE`, `redis-cli FLUSHALL`, `prisma migrate reset`
- container data deletion: Docker volume prune/removal, `docker compose down -v`
- cluster/IaC/cloud deletion: `kubectl delete`, `terraform destroy`, `pulumi destroy`, `aws/gcloud/az` delete/remove commands
- release supply-chain deletion: `npm/pnpm/yarn unpublish`, release deletion, remote tag deletion
- disk/permission destruction: `dd of=/dev/...`, `mkfs`, `diskutil erase`, `chmod -R 777`, broad `chown -R`

Prefer safe previews:

- `git clean -n` before `git clean -f`
- `terraform plan -destroy` before destroy
- `aws s3 rm --dryrun` before recursive S3 deletion
- `docker system df` and `docker volume ls` before pruning
- `kubectl get` and context/namespace checks before deletes

For detailed implementation patterns (secret management, K8s secrets, rotation, scanning), use `/security-audit` skill.
