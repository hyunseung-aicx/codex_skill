#!/bin/bash
# shellcheck shell=bash
# Stop: Session-end MEMORY automation
# 세션 종료 시 오늘의 주요 결정·커밋을 프로젝트 MEMORY.md에 1줄로 자동 append.
# "auto memory" 시스템을 실제 가동 상태로 전환 (CLAUDE.md 템플릿이 있으나 사용자가
# 수동으로 쓰기 어려운 마찰을 해소).
#
# 효과: 활성도 점수 (관점 B) 자동 상승. 6개월 후의 나에게 "왜 이렇게 결정했지?"
#       답을 남겨준다.
#
# Reference: CLAUDE.md "auto memory" 섹션, SETUP_SCORE_2026-04.md 관점 B

# async 동작 — 세션 종료 시 대기 유발하지 않음 (settings에서 async:true)

CWD=$(pwd 2>/dev/null || echo "")
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then exit 0; fi

# git 레포 안에서만 동작
if ! git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# 프로젝트별 memory 디렉토리 결정
# 1순위: 프로젝트 로컬 docs/MEMORY.md 또는 .claude/memory/MEMORY.md
# 2순위: ~/.claude/projects/<hashed>/memory/MEMORY.md
PROJECT_MEM=""
for candidate in \
  "$CWD/.claude/memory/MEMORY.md" \
  "$CWD/docs/MEMORY.md"; do
  dir=$(dirname "$candidate")
  if [ -d "$dir" ] || mkdir -p "$dir" 2>/dev/null; then
    PROJECT_MEM="$candidate"
    break
  fi
done

# fallback to global
if [ -z "$PROJECT_MEM" ]; then
  HASH=$(echo "$CWD" | sed 's|[/: ]|-|g' | head -c 60)
  PROJECT_MEM="${HOME}/.claude/projects/${HASH}/memory/MEMORY.md"
  mkdir -p "$(dirname "$PROJECT_MEM")" 2>/dev/null || exit 0
fi

# 오늘 날짜 이미 기록됐는지 확인 (중복 방지)
TODAY=$(date +%Y-%m-%d)
if [ -f "$PROJECT_MEM" ] && grep -q "^- \[${TODAY}\]" "$PROJECT_MEM" 2>/dev/null; then
  # 이미 오늘자 entry 존재 — 세션 여러 번 끝나도 1회만 기록
  exit 0
fi

# 오늘 커밋 요약 (최대 3개)
TODAY_COMMITS=$(git -C "$CWD" log --since="$TODAY 00:00" --pretty=format:"%s" 2>/dev/null | head -3)
if [ -z "$TODAY_COMMITS" ]; then
  # 커밋이 없으면 최근 1개 커밋 (세션이 밤 넘김 대비)
  TODAY_COMMITS=$(git -C "$CWD" log -1 --pretty=format:"%s" 2>/dev/null)
fi

if [ -z "$TODAY_COMMITS" ]; then
  exit 0  # 기록할 게 없음
fi

BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)

# MEMORY.md 헤더 (첫 생성 시)
if [ ! -f "$PROJECT_MEM" ]; then
  cat > "$PROJECT_MEM" <<EOF
# Project Memory

> 이 파일은 \`memory-writer.sh\` 훅이 세션 종료 시 자동 append.
> 6개월 후의 나에게 "왜 이렇게 결정했지?" 답을 남겨준다.
>
> 형식: \`- [YYYY-MM-DD] <branch>: <commit summary 1줄>\`

EOF
fi

# append — 오늘의 첫 커밋만 (가장 최근 작업 흐름)
FIRST_LINE=$(echo "$TODAY_COMMITS" | head -1 | head -c 100)
echo "- [${TODAY}] ${BRANCH}: ${FIRST_LINE}" >> "$PROJECT_MEM"

# trace 로그
LOG_DIR="${HOME}/.claude/traces"
mkdir -p "$LOG_DIR"
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"MemoryWriter\",\"memFile\":\"${PROJECT_MEM}\",\"session\":\"${CLAUDE_SESSION_ID:-unknown}\"}" >> "${LOG_DIR}/memory-writes.jsonl"

exit 0
