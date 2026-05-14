---
name: budget-aware-coding
description: 무인 자율 운영 시 USD 누적 cap이 토큰 cap보다 우선 — 토큰 80% 가드만으로는 $47K 사고 방지 불가
metadata:
  type: feedback
  valid_from: "2026-05-14"
  valid_until: null
  supersedes: []
  confidence: 0.95
  source: "Anhaia $47K/11d autonomous loop postmortem (dev.to, 2026.03)"
  tags: ["autonomous", "budget", "p0", "harness-v6"]
---

# 무인 운영 비용 통제: 토큰 가드보다 USD cap 우선

자율 에이전트 (Ralph Loop, `/autopilot`)를 운영할 때, 토큰 80% 가드만으로는 폭주 비용 사고를 막을 수 없다.
$47K / 11일 사고(Anhaia)와 $4,200 / 63h 사고(Sattyam Jain)가 정확히 이 패턴이었다.

**Why**: 토큰 가드는 *단일 턴 내* 폭주에 반응한다. 11일 누적 ping-pong은 daily token usage가 일정하면 알람이 안 울린다.
달러 단위 cap이 누적/시간차 폭주를 잡는 유일한 결정적 게이트.

**How to apply**:
- `/autopilot` 사용 시 환경변수로 `CLAUDE_BUDGET_SESSION_USD=5` 이상 설정 금지 (개인 사용 기준)
- 야간 운영 시 `CLAUDE_BUDGET_DAILY_USD=20` 권장 — 초과 시 다음 턴부터 PreToolUse에서 hard block
- Portal26 Agentic Token Controls 패턴 — sub-key를 발급해 worktree별 격리도 권장

**관련 메모리**: [[autonomous-overnight-guardrails]], [[ralph-loop-safety]]

**관련 도구**: `hooks/budget-gate.sh` (Harness v6 P0 후크)
