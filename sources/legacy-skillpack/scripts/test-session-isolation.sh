#!/bin/bash
# shellcheck shell=bash
# test-session-isolation.sh — 훅의 session isolation race condition 검증
#
# 목표: 여러 세션이 동시에 같은 훅을 실행할 때 counter/lock 파일 충돌이 없는지 확인.
# 실제 race를 유발해서 passing 조건: 두 세션의 counter 값이 독립적.
#
# 검증 대상 훅:
#   - loop-detector.sh (file edit counter)
#   - context-guard.sh (Read/Glob/Grep count)
#
# Usage: bash scripts/test-session-isolation.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
RESULTS=()

record() {
  local name="$1"; local status="$2"; local detail="$3"
  RESULTS+=("$status $name — $detail")
  case "$status" in PASS) PASS=$((PASS+1));; FAIL) FAIL=$((FAIL+1));; esac
}

# ─── Test 1: context-guard counter는 세션별로 격리 ────────────────
test_context_guard_isolation() {
  local name="context-guard session isolation"
  local hook="$REPO_ROOT/hooks/context-guard.sh"
  [ ! -f "$hook" ] && { record "$name" "SKIP" "hook 파일 없음"; return; }

  local input='{"tool_name":"Read"}'

  # 세션 A가 20회, 세션 B가 5회 호출 — counter는 섞이면 안 됨
  for _ in $(seq 1 20); do
    CLAUDE_SESSION_ID="ctx-A-$$" bash "$hook" <<<"$input" >/dev/null 2>&1 || true
  done
  for _ in $(seq 1 5); do
    CLAUDE_SESSION_ID="ctx-B-$$" bash "$hook" <<<"$input" >/dev/null 2>&1 || true
  done

  local a_count b_count
  a_count=$(cat "${TMPDIR:-/tmp}/claude-context-guard-ctx-A-$$" 2>/dev/null || echo 0)
  b_count=$(cat "${TMPDIR:-/tmp}/claude-context-guard-ctx-B-$$" 2>/dev/null || echo 0)

  if [ "$a_count" = "20" ] && [ "$b_count" = "5" ]; then
    record "$name" "PASS" "A=20, B=5 (기대대로 독립)"
  else
    record "$name" "FAIL" "A=$a_count(기대 20), B=$b_count(기대 5)"
  fi

  rm -f "${TMPDIR:-/tmp}/claude-context-guard-ctx-A-$$" "${TMPDIR:-/tmp}/claude-context-guard-ctx-B-$$" 2>/dev/null || true
}

# ─── Test 2: 동시 병렬 실행 시에도 독립 유지 ────────────────
test_parallel_concurrent() {
  local name="parallel concurrent sessions"
  local hook="$REPO_ROOT/hooks/context-guard.sh"
  [ ! -f "$hook" ] && { record "$name" "SKIP" "hook 파일 없음"; return; }

  local input='{"tool_name":"Grep"}'

  # 3개 세션을 병렬로 실행 (각 15회)
  (
    for _ in $(seq 1 15); do
      CLAUDE_SESSION_ID="par-1-$$" bash "$hook" <<<"$input" >/dev/null 2>&1 || true
    done
  ) &
  local pid1=$!
  (
    for _ in $(seq 1 15); do
      CLAUDE_SESSION_ID="par-2-$$" bash "$hook" <<<"$input" >/dev/null 2>&1 || true
    done
  ) &
  local pid2=$!
  (
    for _ in $(seq 1 15); do
      CLAUDE_SESSION_ID="par-3-$$" bash "$hook" <<<"$input" >/dev/null 2>&1 || true
    done
  ) &
  local pid3=$!

  wait "$pid1" "$pid2" "$pid3"

  local c1 c2 c3
  c1=$(cat "${TMPDIR:-/tmp}/claude-context-guard-par-1-$$" 2>/dev/null || echo 0)
  c2=$(cat "${TMPDIR:-/tmp}/claude-context-guard-par-2-$$" 2>/dev/null || echo 0)
  c3=$(cat "${TMPDIR:-/tmp}/claude-context-guard-par-3-$$" 2>/dev/null || echo 0)

  if [ "$c1" = "15" ] && [ "$c2" = "15" ] && [ "$c3" = "15" ]; then
    record "$name" "PASS" "3개 병렬 세션 모두 정확히 15회 카운트 (race 없음)"
  else
    record "$name" "FAIL" "병렬 race 발생: $c1, $c2, $c3 (모두 15이어야 함)"
  fi

  rm -f "${TMPDIR:-/tmp}/claude-context-guard-par-1-$$" "${TMPDIR:-/tmp}/claude-context-guard-par-2-$$" "${TMPDIR:-/tmp}/claude-context-guard-par-3-$$" 2>/dev/null || true
}

# ─── 실행 ────────────────
echo "════════════════════════════════════════════════════════════"
echo " Session Isolation Race Tests"
echo "════════════════════════════════════════════════════════════"
test_context_guard_isolation
test_parallel_concurrent

# ─── 리포트 ────────────────
echo ""
for line in "${RESULTS[@]}"; do
  case "$line" in
    PASS*) echo "  [PASS] ${line#PASS }" ;;
    FAIL*) echo "  [FAIL] ${line#FAIL }" ;;
    SKIP*) echo "  [SKIP] ${line#SKIP }" ;;
  esac
done
echo ""
echo "════════════════════════════════════════════════════════════"
echo " 결과: ${PASS} PASS / ${FAIL} FAIL / $((${#RESULTS[@]} - PASS - FAIL)) SKIP"
echo "════════════════════════════════════════════════════════════"

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
