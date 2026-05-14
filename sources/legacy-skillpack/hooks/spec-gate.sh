#!/bin/bash
# shellcheck shell=bash
# PreToolUse(Bash[git commit*]): SPEC-driven gate
# feature/* 또는 refactor/* 브랜치에서 첫 커밋 시 SPEC 문서 존재 확인.
# 없으면 차단 + spec-driven skill 안내.
#
# 우회: 사용자가 "skip spec"/"빨리"라고 직전 메시지에서 명시하면 통과
#       (이 훅은 그것까지 인식 못하므로, 명시 시 SKIP_SPEC_GATE=1 셋업 후 commit)
#
# Reference: rules/spec-driven.md, skills/spec-driven/SKILL.md

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# 정확히 'git commit' 패턴만 검사 (commit --amend, log 등은 제외)
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Branch 확인 — feature/refactor/migration 패턴만 SPEC 강제
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
case "$BRANCH" in
  feature/*|refactor/*|migration/*|feat/*) ;;
  *) exit 0 ;;
esac

# 우회 환경변수
if [ "${SKIP_SPEC_GATE:-0}" = "1" ]; then
  echo "[spec-gate] SKIP_SPEC_GATE=1 → 검증 우회" >&2
  exit 0
fi

# 이 브랜치의 첫 커밋인지 확인 (main 분기 후 커밋 0개)
COMMITS_AHEAD=$(git rev-list --count "main..HEAD" 2>/dev/null || git rev-list --count "master..HEAD" 2>/dev/null || echo 0)
if [ "$COMMITS_AHEAD" -gt 0 ]; then
  # 첫 커밋이 아니면 통과 (브랜치 시작 시 한 번만 검사)
  exit 0
fi

# SPEC 파일 존재 검사 (docs/_drafts/SPEC-*-YYYY-MM-DD.md 또는 SPEC-*.md)
SPEC_FOUND=0
for pattern in "docs/_drafts/SPEC-*.md" "docs/SPEC-*.md" "SPEC.md" "specs/*.md"; do
  for f in $pattern; do
    if [ -f "$f" ]; then
      SPEC_FOUND=1
      break 2
    fi
  done
done

if [ "$SPEC_FOUND" -eq 1 ]; then
  exit 0
fi

# SPEC 없음 → 차단
cat <<'EOF' >&2

╔════════════════════════════════════════════════════════════╗
║  🚫 SPEC GATE — 비trivial 브랜치 첫 커밋 차단              ║
╠════════════════════════════════════════════════════════════╣
║                                                            ║
║  feature/refactor/migration 브랜치는 첫 커밋 전에           ║
║  SPEC 문서 작성이 필요합니다 (rules/spec-driven.md).        ║
║                                                            ║
║  빠른 시작:                                                 ║
║    1. /spec <기능 설명>                                     ║
║       → docs/_drafts/SPEC-<slug>-<YYYY-MM-DD>.md 생성       ║
║       → 5필드(요구/인터페이스/엣지/검증/롤백) 채움           ║
║    2. SPEC 커밋 → 이번 commit 진행                          ║
║                                                            ║
║  우회 (긴급/trivial):                                       ║
║    SKIP_SPEC_GATE=1 git commit ...                          ║
║                                                            ║
║  근거: Addy Osmani — "waterfall in 15 minutes"             ║
║        Anthropic — "spec becomes part of persistent memory"║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF

# decision: block
cat <<'EOF'
{"decision":"block","reason":"SPEC 파일이 없습니다. /spec 커맨드로 먼저 작성하세요. 우회: SKIP_SPEC_GATE=1"}
EOF
exit 0
