# Codex Claude Skillpack Operations

Use this reference when maintaining or debugging the global installation.

## Evidence Basis

- Codex skills are reusable workflows made of `SKILL.md` plus optional `scripts/`, `references/`, and `assets/`; Codex uses progressive disclosure and can load skills in CLI, IDE, and app contexts.
- Codex app commands expose native slash-command behavior; this adapter maps Claude-style command documents to Codex-native execution rather than treating them as runtime hooks.
- SWE-agent's Agent-Computer Interface research shows that clear, purpose-built commands and feedback formats improve software-agent performance. This skillpack therefore provides small terminal commands for update and health checks instead of asking the agent to reason from raw directory state every time.
- Codex use-case guidance emphasizes repeatable workflows, evals, controlled codebase changes, frontend verification, and quality review loops. The doctor/update scripts make the global skillpack auditable and repeatable.

## Maintenance Commands

Run these from any terminal:

```bash
codex-skillpack-doctor
codex-skillpack-update
```

If `/usr/local/bin` is not writable on the machine, use:

```bash
$HOME/.codex/bin/codex-skillpack-doctor
$HOME/.codex/bin/codex-skillpack-update
```

## Doctor Expectations

The doctor should verify:

- Source skill count equals visible Codex GUI/CLI skill count.
- Source skill count equals `$HOME/.agents/skills` visible skill count.
- `commands`, `agents`, `rules`, and `hooks` are linked as reference material.
- Each `SKILL.md` has `name` and `description`.
- The source repo is aligned with `origin/main`, allowing warnings for local Codex adapter files.
