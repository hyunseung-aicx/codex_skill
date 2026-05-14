# Dangerous Command Guardrails

Date: 2026-05-14

## Purpose

This document defines commands that Codex should not run automatically in local, backend, frontend, database, infrastructure, cloud, and release workflows.

The active hook is:

```text
hooks/dangerous-command-blocker.sh
```

It is deliberately conservative. If a command can delete source, erase state, rewrite history, drop data, destroy infrastructure, or remove published artifacts, the harness blocks it and asks for human review.

## Research Summary

Official docs and 2026 agent-safety guidance converge on the same pattern:

- Destructive commands often include a safe preview mode, such as `git clean -n`, `terraform plan -destroy`, or `aws s3 rm --dryrun`.
- Flags like `--force`, `-f`, `--quiet`, `--auto-approve`, and `--recursive` remove human confirmation or expand blast radius.
- Agent workflows should preserve approval boundaries, telemetry, and explicit review before irreversible changes.

Sources used:

- GNU Coreutils `rm` root-preservation behavior: https://www.gnu.org/software/coreutils/manual/html_node/Treating-_002f-specially.html
- Git clean/reset/push docs: https://git-scm.com/docs/git-clean, https://git-scm.com/docs/git-reset, https://git-scm.com/docs/git-push
- PostgreSQL `DROP DATABASE`: https://www.postgresql.org/docs/18/sql-dropdatabase.html
- MySQL `DROP DATABASE`: https://dev.mysql.com/doc/en/drop-database.html
- Prisma `migrate reset`: https://www.prisma.io/docs/cli/migrate/reset
- Docker prune/volumes docs: https://docs.docker.com/engine/manage-resources/pruning/
- Kubernetes delete/drain docs: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_delete/, https://kubernetes.io/docs/reference/kubectl/generated/kubectl_drain/
- Terraform destroy docs: https://developer.hashicorp.com/terraform/cli/commands/destroy
- AWS S3 recursive delete docs: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/s3/rm.html
- Google Cloud instance deletion docs: https://cloud.google.com/sdk/gcloud/reference/compute/instances/delete
- Azure group delete docs: https://learn.microsoft.com/en-us/cli/azure/group
- npm unpublish docs: https://docs.npmjs.com/unpublishing-packages-from-the-registry
- OpenAI Codex safety and telemetry guidance: https://openai.com/index/running-codex-safely/

## Blocked Command Families

| Family | Examples | Why blocked | Safer first step |
| --- | --- | --- | --- |
| Recursive force delete | `rm -rf`, `rm -fr`, `rm --no-preserve-root`, `rm *` | Deletes files with broad scope and little recovery. | `ls`, `find`, dry-run target list, trash/quarantine. |
| Generated bulk delete | `find . -delete`, `xargs rm`, `parallel rm` | Target list may be much larger than intended. | Print targets to a file and review. |
| Project-critical delete | `.git`, `.env`, `src`, `app`, `db`, `migrations`, lockfiles, Docker/K8s/Terraform files | Breaks source control, runtime config, builds, or database history. | Rename/archive, backup branch, or targeted patch. |
| Disk/permission destruction | `dd of=/dev/...`, `mkfs`, `diskutil erase`, `chmod -R 777`, `chown -R /` | Can destroy disks or remove OS/project security boundaries. | Explicit manual approval only. |
| Git destruction | `git reset --hard`, `git clean -fdx`, `git push --force`, `git filter-repo`, `git reflog expire --expire=now` | Discards local changes, ignored files, remote history, or recovery paths. | `git status`, `git diff`, `git clean -n`, backup branch. |
| SQL/DB destruction | `DROP DATABASE`, `DROP TABLE`, `TRUNCATE`, `DELETE FROM table` without `WHERE`, `redis-cli FLUSHALL` | Drops or clears durable data. | Transaction, backup, staging DB, explicit WHERE and row count. |
| ORM reset | `prisma migrate reset --force`, `prisma db push --force-reset`, `rails db:drop`, `supabase db reset` | Drops/recreates schema and loses data. | Confirm dev DB, backup, migration diff. |
| Docker state removal | `docker system prune -a --volumes`, `docker volume prune`, `docker compose down -v` | Volumes often contain databases and local service state. | `docker system df`, `docker volume ls`, targeted container cleanup. |
| Kubernetes deletion | `kubectl delete`, `kubectl drain`, `kubectl scale --replicas=0`, finalizer patch | Deletes workloads or disables scheduling; wrong context/namespace is common. | `kubectl config current-context`, `kubectl get`, manifest diff. |
| IaC destruction | `terraform destroy`, `terraform apply -destroy`, `terraform apply -auto-approve`, `terraform state rm`, `pulumi destroy` | Deprovisions cloud resources or mutates state. | `terraform plan`, `terraform plan -destroy`, workspace/account check. |
| Cloud resource deletion | `aws s3 rm --recursive`, `aws s3 rb --force`, `gcloud ... delete --quiet`, `az group delete --yes` | Deletes remote data/infrastructure, often outside local repo recovery. | Dry-run/list resources, confirm account/project/region. |
| Registry/release deletion | `npm unpublish`, `pnpm unpublish`, `gh release delete`, remote tag deletion | Breaks downstream consumers and removes published artifacts. | Deprecate, yank with policy review, publish fixed version. |

## Policy

1. Codex may inspect and explain dangerous commands.
2. Codex may propose a safe dry-run or read-only alternative.
3. Codex must not run blocked commands automatically.
4. A human can still run them manually outside the harness after confirming:
   - target account/project/cluster/database
   - backup or rollback path
   - expected objects affected
   - reason this cannot be done with a safer command

## Safe Alternatives

| Intent | Safer command |
| --- | --- |
| See what `git clean` would delete | `git clean -n` or `git clean -ndx` |
| See Terraform destroy impact | `terraform plan -destroy` |
| Preview S3 deletion | `aws s3 rm s3://bucket/prefix --recursive --dryrun` |
| Inspect Docker cleanup | `docker system df`, `docker volume ls` |
| Inspect Kubernetes target | `kubectl config current-context`, `kubectl get all -n <namespace>` |
| Remove local generated files | Delete explicit files after `find ... -print` review |
| Change permissions | Target exact file or directory; avoid recursive root/project operations |

## Test Samples

The hook should block:

```bash
rm -rf src
git clean -fdx
git reset --hard
terraform destroy -auto-approve
aws s3 rm s3://prod-bucket --recursive
npx prisma migrate reset --force
kubectl delete namespace prod
docker system prune -a --volumes -f
chmod -R 777 .
npm unpublish my-package -f
```

The hook should allow:

```bash
git status --short
git clean -n
terraform plan -destroy
aws s3 rm s3://prod-bucket --recursive --dryrun
docker system df
kubectl get all -n dev
```

## Maintenance

When adding a new tool family:

1. Prefer official vendor documentation.
2. Add the risky command pattern to `hooks/dangerous-command-blocker.sh`.
3. Add a safe preview alternative to this document.
4. Add at least one manual hook test command before committing.
