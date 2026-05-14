#!/bin/bash
# shellcheck shell=bash
# score-setup.sh — Claude Code 셋업 자동 점수 산출
#
# Usage:
#   bash scripts/score-setup.sh                  # repo root에서 실행 (현재 source 측정)
#   bash scripts/score-setup.sh ~/.claude        # 설치된 ~/.claude 측정
#   bash scripts/score-setup.sh --json           # JSON 출력 (CI 친화)
#
# 출력: SETUP_SCORE_2026-04.md 점수표와 동일 산식. 누구나 재현 가능.
#
# Reference: SETUP_SCORE_2026-04.md "측정 재현 스크립트" 섹션

set -euo pipefail

# 입력 처리
TARGET_DIR="${1:-$(pwd)}"
OUT_JSON=0
if [ "${1:-}" = "--json" ]; then
  TARGET_DIR=$(pwd)
  OUT_JSON=1
elif [ "${2:-}" = "--json" ]; then
  OUT_JSON=1
fi

# settings.json 위치 결정
SETTINGS_FILE=""
for f in "$TARGET_DIR/settings.local.json" "$TARGET_DIR/settings.json"; do
  [ -f "$f" ] && { SETTINGS_FILE="$f"; break; }
done

if [ -z "$SETTINGS_FILE" ]; then
  echo "ERROR: settings.json not found in $TARGET_DIR" >&2
  exit 2
fi

# 자원 카운트
hook_count() { ls "$TARGET_DIR/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' '; }
agent_count() { ls "$TARGET_DIR/agents/"*.md 2>/dev/null | wc -l | tr -d ' '; }
skill_count() { find "$TARGET_DIR/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' '; }
command_count() { ls "$TARGET_DIR/commands/"*.md 2>/dev/null | wc -l | tr -d ' '; }
rule_count() { ls "$TARGET_DIR/rules/"*.md 2>/dev/null | wc -l | tr -d ' '; }
claude_md_lines() {
  local f="$TARGET_DIR/CLAUDE.md"
  [ -f "$f" ] && wc -l < "$f" | tr -d ' ' || echo 0
}

H=$(hook_count); A=$(agent_count); SK=$(skill_count)
C=$(command_count); R=$(rule_count); CMD_LINES=$(claude_md_lines)

# settings.json 분석 — jq가 있으면 사용, 없으면 python fallback (Windows 친화)
if command -v jq >/dev/null 2>&1; then
  EVENTS=$(jq '.hooks | keys | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
  HANDLERS=$(jq '[.hooks[][].hooks[]] | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
  ALLOW=$(jq '.permissions.allow | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
  DENY=$(jq '.permissions.deny | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
  PLUGINS=$(jq '(.enabledPlugins // {}) | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
else
  # Python fallback (jq가 없는 Windows/CI 환경) — env로 경로 전달 (공백 안전)
  STATS=$(SETTINGS_PATH="$SETTINGS_FILE" PYTHONIOENCODING=utf-8 python -c '
import json, os
with open(os.environ["SETTINGS_PATH"], encoding="utf-8") as f: s = json.load(f)
hooks = s.get("hooks", {})
print(len(hooks),
      sum(len(h.get("hooks", [])) for ev in hooks.values() for h in ev),
      len(s.get("permissions", {}).get("allow", [])),
      len(s.get("permissions", {}).get("deny", [])),
      len(s.get("enabledPlugins", {})))
' 2>/dev/null)
  read -r EVENTS HANDLERS ALLOW DENY PLUGINS <<< "$STATS"
  EVENTS=${EVENTS:-0}; HANDLERS=${HANDLERS:-0}
  ALLOW=${ALLOW:-0}; DENY=${DENY:-0}; PLUGINS=${PLUGINS:-0}
fi

# ═══════════════════════════════════════════════════════════════════
# 점수 산식 (v2, 2026-04 재조정)
#
# 기준: 외부 공개 dotfiles 샘플(awesome-claude-code-subagents, karanb192/hooks,
#       공식 claude-plugins-official 등) 조사로 추정한 median·p75 분포.
#       "나의 현재 값 = 만점" 편향 제거. 공식 기준(27 events 등) 사용.
#
# 분모 근거:
#   - events:   27 공식 이벤트 (code.claude.com/docs/en/hooks)
#   - agents:   median ~5, p75 ~12, p95 ~20  → 24+ 는 상위 5%
#   - skills:   median ~3, p75 ~10, p95 ~25  → 38 = 상위 5%
#   - commands: median ~5, p75 ~15, p95 ~28  → 33 = 상위 5%
#   - rules:    median ~2, p75 ~6,  p95 ~12  → 16 = 상위 5%
#
# 산식: 해당 percentile = 해당 점수 (50, 70, 85, 95).
#       그 이상은 overkill로 간주, 점수 안 올라감 (anti-pattern 경계).
# ═══════════════════════════════════════════════════════════════════

score_harness() {
  # 공식 27 events 중 일반 개발자가 실제 운용 가능한 이벤트 약 20개.
  # (Task/Teammate/Elicitation 등은 특수 — 분모에서 제외)
  # 계단식 기준: median 5, p75 11, p95 18.
  local base
  if   [ "$EVENTS" -ge 20 ]; then base=92   # 거의 모든 활용 가능 이벤트 커버
  elif [ "$EVENTS" -ge 14 ]; then base=82   # 고급 수준 (현재 위치)
  elif [ "$EVENTS" -ge 10 ]; then base=70
  elif [ "$EVENTS" -ge 5 ]; then  base=55
  else base=$((EVENTS * 10))
  fi
  # handler 풍부도: median 12, p75 25
  if [ "$HANDLERS" -ge 25 ]; then base=$((base + 6))
  elif [ "$HANDLERS" -ge 12 ]; then base=$((base + 3))
  fi
  [ "$base" -gt 95 ] && base=95
  echo "$base"
}
score_subagent() {
  # 외부 dotfiles median 5, p75 12. 20+ 는 이미 상위 5%. 25+ 는 과잉 경고.
  if [ "$A" -ge 30 ]; then echo 88   # 과잉 — Anthropic "entire ecosystem" 경고
  elif [ "$A" -ge 20 ]; then echo 92
  elif [ "$A" -ge 12 ]; then echo 82
  elif [ "$A" -ge 5 ]; then echo 65
  else echo $((A * 10))
  fi
}
score_skills() {
  # 외부 median 3, p75 10, p95 25. 30+ 는 anti-pattern 경계.
  if [ "$SK" -ge 40 ]; then echo 82   # 과잉 경고
  elif [ "$SK" -ge 25 ]; then echo 92
  elif [ "$SK" -ge 10 ]; then echo 78
  elif [ "$SK" -ge 3 ]; then echo 55
  else echo $((SK * 12))
  fi
}
score_commands() {
  # 외부 median 5, p75 15, p95 28. 30+ = anti-pattern ("magic commands" 경고)
  if [ "$C" -ge 35 ]; then echo 72   # 과잉 경고
  elif [ "$C" -ge 25 ]; then echo 88
  elif [ "$C" -ge 15 ]; then echo 80
  elif [ "$C" -ge 5 ]; then echo 60
  else echo $((C * 10))
  fi
}
score_rules() {
  # 외부 median 2, p75 6, p95 12.
  # CLAUDE.md 줄 수 ≤ 50 = +보너스 (Anthropic best practice)
  # 15+ 는 과잉 경고 (rules 끼리 중복 위험)
  local s
  if [ "$R" -ge 18 ]; then s=75   # 과잉
  elif [ "$R" -ge 12 ]; then s=90
  elif [ "$R" -ge 6 ]; then s=82
  elif [ "$R" -ge 2 ]; then s=60
  else s=$((R * 15))
  fi
  # CLAUDE.md 50줄 이하 → +5, 100줄 초과 → -10
  if [ "$CMD_LINES" -gt 0 ] && [ "$CMD_LINES" -le 50 ]; then
    s=$((s + 5))
  elif [ "$CMD_LINES" -gt 100 ]; then
    s=$((s - 10))
  fi
  [ "$s" -gt 95 ] && s=95
  echo "$s"
}
score_perms() {
  # 안전한 zone: allow 20-50, deny 2+
  local s=85
  if [ "$ALLOW" -lt 15 ]; then s=70
  elif [ "$ALLOW" -gt 80 ]; then s=70  # 너무 많이 열면 위험
  fi
  [ "$DENY" -lt 2 ] && s=$((s - 10))
  echo "$s"
}
score_session() {
  # session-isolation: 전부 lock 사용 가정 — 정성평가, 93 고정
  echo 93
}
score_mcp() {
  # mcp-patterns.md 존재만 확인. 실 server 수는 settings에 안 보일 수도.
  [ -f "$TARGET_DIR/rules/mcp-patterns.md" ] && echo 85 || echo 60
}
score_marketplace() {
  # 자체 marketplace manifest가 공식 스키마를 따르는지 검증
  local manifest="$TARGET_DIR/.claude-plugin/marketplace.json"
  if [ -f "$manifest" ]; then
    # 필수 필드: $schema가 anthropic 스키마, plugins 배열
    local valid=0
    if command -v python >/dev/null 2>&1; then
      valid=$(MANIFEST_PATH="$manifest" python -c '
import json, os, sys
try:
    with open(os.environ["MANIFEST_PATH"], encoding="utf-8") as f: m = json.load(f)
    schema_ok = "anthropic.com/claude-code/marketplace" in m.get("$schema", "")
    plugins_ok = isinstance(m.get("plugins"), list) and len(m["plugins"]) >= 1
    plugin0 = m["plugins"][0] if plugins_ok else {}
    required_ok = all(k in plugin0 for k in ("name", "source", "category", "description"))
    print(1 if (schema_ok and plugins_ok and required_ok) else 0)
except Exception: print(0)
' 2>/dev/null)
    fi
    if [ "${valid:-0}" = "1" ]; then echo 90
    else echo 55  # 파일은 있으나 공식 스키마 불일치
    fi
  elif [ "$PLUGINS" -ge 1 ]; then echo 70
  else echo 45
  fi
}
score_trend() {
  # 2026 트렌드 정합성: spec-driven, error-recovery, context-guard 같은 신트렌드 reflect
  local s=80
  [ -d "$TARGET_DIR/skills/spec-driven" ] && s=$((s + 5))
  [ -d "$TARGET_DIR/skills/error-recovery" ] && s=$((s + 5))
  [ -f "$TARGET_DIR/hooks/context-guard.sh" ] && s=$((s + 5))
  [ -f "$TARGET_DIR/rules/senior-fundamentals.md" ] && s=$((s + 4))
  [ "$s" -gt 99 ] && s=99
  echo "$s"
}

S_HARNESS=$(score_harness)
S_SUBAGENT=$(score_subagent)
S_SKILLS=$(score_skills)
S_COMMANDS=$(score_commands)
S_RULES=$(score_rules)
S_PERMS=$(score_perms)
S_SESSION=$(score_session)
S_MCP=$(score_mcp)
S_MARKET=$(score_marketplace)
S_TREND=$(score_trend)

TOTAL=$((S_HARNESS + S_SUBAGENT + S_SKILLS + S_COMMANDS + S_RULES + S_PERMS + S_SESSION + S_MCP + S_MARKET + S_TREND))

# 등급
if [ "$TOTAL" -ge 950 ]; then GRADE="S"
elif [ "$TOTAL" -ge 900 ]; then GRADE="A+"
elif [ "$TOTAL" -ge 850 ]; then GRADE="A"
elif [ "$TOTAL" -ge 800 ]; then GRADE="A-"
elif [ "$TOTAL" -ge 700 ]; then GRADE="B+"
elif [ "$TOTAL" -ge 600 ]; then GRADE="B"
else GRADE="C 이하"
fi

# 출력
if [ "$OUT_JSON" -eq 1 ]; then
  cat <<EOF
{
  "target": "$TARGET_DIR",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "resources": {
    "hooks": $H, "agents": $A, "skills": $SK, "commands": $C, "rules": $R,
    "events": $EVENTS, "handlers": $HANDLERS,
    "allow": $ALLOW, "deny": $DENY, "plugins": $PLUGINS,
    "claudeMdLines": $CMD_LINES
  },
  "scores": {
    "harness": $S_HARNESS, "subagent": $S_SUBAGENT, "skills": $S_SKILLS,
    "commands": $S_COMMANDS, "rules": $S_RULES, "permissions": $S_PERMS,
    "sessionIsolation": $S_SESSION, "mcp": $S_MCP,
    "marketplace": $S_MARKET, "trendAlignment": $S_TREND
  },
  "total": $TOTAL,
  "grade": "$GRADE"
}
EOF
else
  cat <<EOF
═══════════════════════════════════════════════════════════
 Claude Code 셋업 점수 — $(date '+%Y-%m-%d %H:%M')
 대상: $TARGET_DIR
═══════════════════════════════════════════════════════════

[자원 카운트]
  hooks:    $H        skills:   $SK        rules:    $R
  agents:   $A        commands: $C        CLAUDE.md: $CMD_LINES lines
  events:   $EVENTS/14    handlers: $HANDLERS
  allow:    $ALLOW    deny:     $DENY    plugins:  $PLUGINS

[차원별 점수]
  Harness coverage      $S_HARNESS / 98
  Subagent library      $S_SUBAGENT / 95
  Skills breadth        $S_SKILLS / 96
  Commands + auto-link  $S_COMMANDS / 94
  Rules clarity         $S_RULES / 95
  Permissions hygiene   $S_PERMS / 90
  Session isolation     $S_SESSION / 95
  MCP integration       $S_MCP / 90
  Plugin / Marketplace  $S_MARKET / 90
  Trend alignment 2026  $S_TREND / 99

═══════════════════════════════════════════════════════════
 합계: $TOTAL / 1000   등급: $GRADE
═══════════════════════════════════════════════════════════

EOF
fi
