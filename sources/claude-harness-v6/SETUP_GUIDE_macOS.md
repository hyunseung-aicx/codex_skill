# 맥북 셋업 가이드 — Claude Code Harness v6

> macOS에서 이 레포의 9가지 개선을 적용하는 **완전한 가이드**.
> 처음 사용하는 사람도 따라할 수 있도록 명령어 한 줄 한 줄 풀어서 설명합니다.

---

## 📚 목차

1. [준비물 (사전 요구사항)](#1-준비물-사전-요구사항)
2. [설치 시나리오 — 어느 경로에 둘지 결정](#2-설치-시나리오--어느-경로에-둘지-결정)
3. [시나리오 A — 전역 경로 (~/.claude/)에 통합](#3-시나리오-a--전역-경로-claude에-통합)
4. [시나리오 B — 커스텀 경로 (별도 디렉토리)](#4-시나리오-b--커스텀-경로-별도-디렉토리)
5. [환경변수 설정](#5-환경변수-설정)
6. [settings.json 머지](#6-settingsjson-머지)
7. [동작 확인 (검증 체크리스트)](#7-동작-확인-검증-체크리스트)
8. [사용 방법 — 일상 사용 시나리오](#8-사용-방법--일상-사용-시나리오)
9. [트러블슈팅](#9-트러블슈팅)
10. [내 셋업 트리 구조 (한국어)](#10-내-셋업-트리-구조-한국어)

---

## 1. 준비물 (사전 요구사항)

### 1-1. 필수 도구

```bash
# Homebrew (없다면 설치)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 필수 패키지
brew install jq curl git
```

| 도구 | 확인 명령 | 용도 |
|------|----------|------|
| `bash` 5.0+ | `bash --version` | macOS 기본은 3.2 — Homebrew bash 권장 |
| `jq` | `jq --version` | 모든 후크의 JSON 파싱 |
| `curl` | `curl --version` | `llm-judge.sh` API 호출 |
| `git` | `git --version` | 레포 클론 |
| `shasum` | `which shasum` | `tool-hash-dedup.sh` (기본 제공) |
| `awk` | `which awk` | `budget-gate.sh` (기본 제공) |
| Claude Code | `claude --version` | 메인 CLI |

### 1-2. Claude Code 설치 (없다면)

[공식 설치 가이드](https://code.claude.com/docs/en/install) 참조. 빠른 설치:

```bash
curl -fsSL https://claude.com/install.sh | sh
claude --version   # 1.x.x 출력 확인
```

### 1-3. Anthropic API Key

`llm-judge.sh` 후크가 Haiku 호출용으로 필요. [console.anthropic.com](https://console.anthropic.com/) 에서 발급.

```bash
# 발급받은 키를 안전한 위치에 보관 (예: ~/.claude/.env)
mkdir -p ~/.claude
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.claude/.env
chmod 600 ~/.claude/.env
```

---

## 2. 설치 시나리오 — 어느 경로에 둘지 결정

| 시나리오 | 장점 | 단점 | 추천 대상 |
|---------|------|------|----------|
| **A. 전역 경로 통합** (`~/.claude/hooks/`에 직접) | Claude Code가 기본으로 인식, 환경변수 1개로 시작 | 기존 후크와 이름 충돌 시 덮어쓸 위험 | Claude Code 처음 사용 / 셋업 통째로 교체 |
| **B. 커스텀 경로** (예: `~/My_ClaudeCode_Skill_v6/`) | 기존 셋업 보존, git 관리, 여러 버전 병행 가능 | `CLAUDE_SKILL_DIR` 환경변수 + settings.json에 절대경로 명시 필요 | **권장** — 기존 셋업이 있거나 git으로 버전 관리하고 싶을 때 |

이 가이드는 **B (커스텀 경로)** 를 권장합니다. 안전하고, 나중에 rollback 쉬움.

---

## 3. 시나리오 A — 전역 경로 (`~/.claude/`)에 통합

> ⚠️ 기존 `~/.claude/hooks/`에 동일 이름 후크가 있으면 덮어쓰지 마세요. 시나리오 B를 사용하세요.

### Step 1. 클론 후 직접 복사

```bash
# 1) 임시 디렉토리에 클론
git clone https://github.com/hyunseung-aicx/claude_skill.git /tmp/claude_skill_v6
cd /tmp/claude_skill_v6

# 2) 후크 파일 복사
cp -i hooks/*.sh ~/.claude/hooks/      # -i 옵션: 덮어쓰기 확인
cp -i agents/*.md ~/.claude/agents/
cp -r memory-schema ~/.claude/

# 3) 실행 권한
chmod +x ~/.claude/hooks/*.sh

# 4) 임시 디렉토리 정리
rm -rf /tmp/claude_skill_v6
```

### Step 2. 환경변수 등록 ([Step 5번 절](#5-환경변수-설정) 참조)

이 시나리오에서는 `CLAUDE_SKILL_DIR="$HOME/.claude"` 설정.

### Step 3. settings.json 머지 ([Step 6번 절](#6-settingsjson-머지) 참조)

---

## 4. 시나리오 B — 커스텀 경로 (별도 디렉토리)

> **이 방식 권장.** 기존 셋업과 격리되고, git으로 버전 관리 가능합니다.

### Step 1. 원하는 경로에 클론

```bash
# 원하는 위치 선택. 예시 경로들:
#   ~/My_ClaudeCode_Skill_v6     ← 사용자 홈
#   ~/Documents/claude_skill       ← Documents 폴더
#   ~/Desktop/dev/claude_skill     ← 개발 폴더

# 예: 홈 디렉토리에 클론
cd ~
git clone https://github.com/hyunseung-aicx/claude_skill.git claude_skill_v6
cd claude_skill_v6

# 절대 경로 확인 (이게 CLAUDE_SKILL_DIR 값)
pwd
# /Users/yourname/claude_skill_v6
```

### Step 2. 실행 권한 부여

```bash
chmod +x hooks/*.sh scripts/*.sh
ls -la hooks/   # 모두 -rwxr-xr-x 확인
```

### Step 3. (선택) ~/.claude 와 심볼릭 링크

기존 후크와 격리된 채로 Claude Code가 인식하게 하려면 settings.json에 절대경로를 쓰면 됩니다 ([Step 6번 절](#6-settingsjson-머지)).

심볼릭 링크를 선호하면:

```bash
# 신규 후크만 심볼릭 링크 (기존 후크 보존)
for hook in hooks/*.sh; do
    name=$(basename "$hook")
    # 기존 ~/.claude/hooks/에 같은 이름 있으면 skip
    if [ -e ~/.claude/hooks/"$name" ]; then
        echo "⚠️ Skip (already exists): $name"
        continue
    fi
    ln -sv "$(pwd)/$hook" ~/.claude/hooks/"$name"
done
```

---

## 5. 환경변수 설정

`~/.zshrc` (또는 `~/.bash_profile`) 에 추가합니다.

### Step 1. 셸 확인

```bash
echo $SHELL
# /bin/zsh    → ~/.zshrc 편집
# /bin/bash   → ~/.bash_profile 편집
```

### Step 2. 환경변수 추가

```bash
# zsh 사용자
cat >> ~/.zshrc <<'EOF'

# ───── Claude Code Harness v6 ─────
# 이 레포의 절대 경로 (시나리오 A는 ~/.claude, 시나리오 B는 클론한 경로)
export CLAUDE_SKILL_DIR="$HOME/claude_skill_v6"

# Anthropic API Key (llm-judge.sh 용)
[ -f "$HOME/.claude/.env" ] && source "$HOME/.claude/.env"

# 예산 cap (개인 사용 기준; 야간 운영 시 더 올리기)
export CLAUDE_BUDGET_SESSION_USD=5
export CLAUDE_BUDGET_DAILY_USD=20
export CLAUDE_BUDGET_MODE=block

# LLM Judge (초기 도입은 warn 권장)
export CLAUDE_JUDGE_MODE=warn
# export CLAUDE_JUDGE_DISABLE=1   # 완전히 끄려면 주석 해제

# Tool dedup
export CLAUDE_DEDUP_THRESHOLD=5
export CLAUDE_DEDUP_MODE=warn

# Bench (선택)
export CLAUDE_BENCH_MODEL=claude-sonnet-4-6
# ──────────────────────────────────
EOF

# 즉시 적용
source ~/.zshrc
```

### Step 3. 환경변수 확인

```bash
echo "SKILL_DIR: $CLAUDE_SKILL_DIR"
echo "API_KEY exists: $([ -n "$ANTHROPIC_API_KEY" ] && echo yes || echo no)"
echo "BUDGET: \$$CLAUDE_BUDGET_SESSION_USD / \$$CLAUDE_BUDGET_DAILY_USD"
```

기대 출력:
```
SKILL_DIR: /Users/yourname/claude_skill_v6
API_KEY exists: yes
BUDGET: $5 / $20
```

---

## 6. settings.json 머지

### Step 1. 기존 settings.json 백업

```bash
# 백업 (날짜 포함)
cp ~/.claude/settings.json ~/.claude/settings.json.backup-$(date +%Y%m%d-%H%M%S)
```

### Step 2. 예제 파일 확인

```bash
cat $CLAUDE_SKILL_DIR/settings/settings.example.json
```

### Step 3. 머지 방식 선택

**옵션 1 — 새 셋업 (기존 후크 없음)**:
```bash
# 그대로 복사 (시나리오 A인 경우 $CLAUDE_SKILL_DIR이 $HOME/.claude 이므로 자동 치환됨)
envsubst < $CLAUDE_SKILL_DIR/settings/settings.example.json > ~/.claude/settings.json
```

**옵션 2 — 기존 셋업과 머지 (권장)**:

`jq`로 안전하게 머지:

```bash
# 기존 hooks를 살리면서 v6 hooks 추가
jq -s '
  .[0] as $existing |
  .[1] as $new |
  $existing * {
    "hooks": (
      ($existing.hooks // {}) as $eh |
      ($new.hooks // {}) as $nh |
      ($eh | keys + ($nh | keys)) | unique | map({
        (.): (($eh[.] // []) + ($nh[.] // []))
      }) | add
    )
  }
' ~/.claude/settings.json $CLAUDE_SKILL_DIR/settings/settings.example.json \
  | envsubst > ~/.claude/settings.json.new

# 결과 확인 후 적용
diff ~/.claude/settings.json ~/.claude/settings.json.new
mv ~/.claude/settings.json.new ~/.claude/settings.json
```

**옵션 3 — 수동 (안전 최우선)**:

`settings.example.json`을 보면서 직접 `~/.claude/settings.json`의 `hooks` 필드에 추가. `${CLAUDE_SKILL_DIR}` 부분은 절대 경로로 치환.

### Step 4. settings.json 유효성 검증

```bash
# JSON 문법 체크
jq . ~/.claude/settings.json > /dev/null && echo "✓ Valid JSON" || echo "✗ Invalid JSON"

# 후크 경로 확인
jq -r '.hooks | .. | .command? // empty' ~/.claude/settings.json | sort -u
```

각 후크 명령이 절대 경로로 존재해야 합니다.

---

## 7. 동작 확인 (검증 체크리스트)

### 7-1. 후크 단독 실행 테스트

```bash
# prompt-cache-monitor (transcript 없으면 silent pass)
echo '{}' | bash $CLAUDE_SKILL_DIR/hooks/prompt-cache-monitor.sh
echo "Exit: $?"  # 0 기대

# budget-gate (transcript 없으면 silent pass)
echo '{}' | bash $CLAUDE_SKILL_DIR/hooks/budget-gate.sh
echo "Exit: $?"  # 0 기대

# tool-hash-dedup (Read 도구는 skip)
echo '{"session_id":"test","tool_name":"Read","tool_input":{"file_path":"/tmp/x"}}' | \
    bash $CLAUDE_SKILL_DIR/hooks/tool-hash-dedup.sh
echo "Exit: $?"  # 0 기대

# model-router (간단한 프롬프트 → sonnet 추천)
echo '{"session_id":"test","prompt":"리팩토링해줘"}' | \
    bash $CLAUDE_SKILL_DIR/hooks/model-router.sh
# {"hookSpecificOutput":...} JSON 출력 기대 (opus 추천)
```

### 7-2. trace 디렉토리 생성 확인

```bash
ls -la ~/.claude/traces/
# cache-metrics.jsonl, budget.jsonl 등 생성됨
```

### 7-3. Claude Code 새 세션에서 동작 확인

```bash
# Claude Code 새 세션 시작
claude

# 세션에서 간단한 prompt 입력: "현재 디렉토리 확인해줘"
# → model-router의 추천 메시지가 컨텍스트에 주입됨
```

### 7-4. LLM Judge 테스트 (API key 필요)

```bash
# 임시 git 디렉토리에서 테스트
cd /tmp && mkdir judge-test && cd judge-test && git init -q
echo "function foo() { /* TODO */ }" > foo.js
git add . && git commit -q -m "test"
echo "function foo() { /* still TODO */ }" > foo.js

# 모의 transcript 작성 (간이)
TS=$(mktemp)
echo '{"message":{"role":"user","content":"Implement foo() that returns 42"}}' > "$TS"

# Judge 실행
echo "{\"session_id\":\"test\",\"transcript_path\":\"$TS\",\"cwd\":\"$(pwd)\"}" | \
    bash $CLAUDE_SKILL_DIR/hooks/llm-judge.sh

# ~/.claude/traces/llm-judge.jsonl 에 결과 기록됨
cat ~/.claude/traces/llm-judge.jsonl | tail -1 | jq .
```

기대 결과: `verdict: BLOCK`, reason에 "TODO 그대로", "구현 안 됨" 등 언급.

### 7-5. 체크리스트

- [ ] `~/.claude/traces/` 에 후크별 jsonl 파일 생성됨
- [ ] `model-router` 가 옵스/소넷 추천 메시지를 컨텍스트에 주입함
- [ ] `budget-gate` 가 ~/.claude/budget-state/ 디렉토리 생성함
- [ ] `llm-judge` 가 API 호출 후 verdict 기록함
- [ ] Claude Code 세션 시작 시 에러 메시지 없음
- [ ] `jq . ~/.claude/settings.json` 통과

---

## 8. 사용 방법 — 일상 사용 시나리오

### 8-1. 일반 코딩 작업 (자동으로 동작)

특별히 할 일 없음. 모든 후크가 자동 발동:
- 프롬프트 입력 시 → `model-router` 가 모델 추천 (Haiku/Sonnet/Opus)
- 도구 사용 시 → `budget-gate` 가 USD 누적 체크, `tool-hash-dedup` 가 ping-pong 감지
- 세션 종료 시 → `llm-judge` 가 diff 평가, `prompt-cache-monitor` 가 cache hit rate 기록

### 8-2. 무인 야간 운영 (`/autopilot`)

```bash
# 야간 6시간 자율 작업
/autopilot 6 ~/Desktop/TODO-tonight.md

# 환경변수 임시 override (야간만 cap 상향)
CLAUDE_BUDGET_DAILY_USD=50 CLAUDE_JUDGE_MODE=block /autopilot 6 TODO.md
```

가드레일이 자동으로 다음을 차단:
- 누적 비용 $50 초과 → 새 도구 사용 block
- 같은 tool 호출 5회+ → block
- LLM Judge가 BLOCK 판정 → 다음 턴 차단

### 8-3. 비용 모니터링

```bash
# 오늘까지 누적 비용 확인
tail -1 ~/.claude/traces/budget.jsonl | jq '{daily_cost_usd, daily_pct}'

# 세션별 비용 TOP 5
jq -s 'sort_by(.session_cost_usd) | reverse | .[0:5] | .[] | {session_id, cost: .session_cost_usd}' \
    ~/.claude/traces/budget.jsonl
```

### 8-4. Cache hit rate 확인

```bash
# 평균 cache hit rate
jq -s 'map(.hit_rate) | add / length' ~/.claude/traces/cache-metrics.jsonl

# 70% 미만 세션 알람
cat ~/.claude/traces/cache-warnings.jsonl 2>/dev/null
```

70% 미달 시 `settings.json`의 system prompt에 `cache_control` 명시 확인.

### 8-5. Self-Bench 실행

```bash
# 수동 실행
bash $CLAUDE_SKILL_DIR/hooks/bench-runner.sh

# nightly cron 등록
crontab -e
# 추가:
0 3 * * * /bin/bash $HOME/claude_skill_v6/hooks/bench-runner.sh >> $HOME/.claude/traces/bench-cron.log 2>&1
```

벤치 task 디렉토리 초기 셋업은 [`hooks/bench-runner.sh`](./hooks/bench-runner.sh) 주석 참조.

### 8-6. OTel trace 활용

```bash
# 기존 trace를 OTel 형식으로 일괄 변환
bash $CLAUDE_SKILL_DIR/scripts/migrate-to-otel.sh \
    ~/.claude/traces/2026-05-14.jsonl > /tmp/otel-2026-05-14.jsonl

# Datadog/Langfuse에 import (각 도구의 OTel collector 사용)
```

### 8-7. Judge Agent 호출 (서브에이전트로)

`coordinator` 또는 자동 트리거가 호출. 수동으로는:

```
@judge-agent 현재 변경사항을 평가해주세요.
```

---

## 9. 트러블슈팅

### Q1. "command not found: jq"

```bash
brew install jq
```

### Q2. 후크가 동작하지 않음

```bash
# 1) 권한 확인
ls -la $CLAUDE_SKILL_DIR/hooks/*.sh
# 모두 -rwxr-xr-x 여야 함. 아니면:
chmod +x $CLAUDE_SKILL_DIR/hooks/*.sh

# 2) settings.json 경로 확인
jq -r '.hooks | .. | .command? // empty' ~/.claude/settings.json
# 절대경로여야 함. ${CLAUDE_SKILL_DIR} 가 남아있으면 미치환.

# 3) Claude Code 재시작
# 새 세션 시작
```

### Q3. budget-gate가 늘 0원 보고

```bash
# transcript 경로 확인
ls -la /tmp/claude-* 2>/dev/null  # 또는 Claude Code transcript 디렉토리

# usage 필드 존재 확인
jq -s 'map(.message.usage) | map(select(. != null))' <transcript-path>
```

usage 필드 없으면 Claude Code 버전 확인 — 2026.04+ 필요합니다.

### Q4. LLM Judge가 항상 PASS

```bash
# API key 확인
echo $ANTHROPIC_API_KEY | head -c 10
# sk-ant-... 출력되어야 함

# 직접 호출 테스트
curl -sS https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d '{"model":"claude-haiku-4-5-20251001","max_tokens":50,"messages":[{"role":"user","content":"hi"}]}' \
    | jq -r '.content[0].text // .error.message'
```

### Q5. "Permission denied" — settings.json 수정

```bash
# 소유자 확인
ls -la ~/.claude/settings.json
# 본인 소유여야 함. 아니면:
sudo chown $(whoami) ~/.claude/settings.json
```

### Q6. 전체 비활성화 (긴급)

모든 v6 후크를 환경변수로 끄기:
```bash
export CLAUDE_JUDGE_DISABLE=1
export CLAUDE_BUDGET_MODE=warn
export CLAUDE_DEDUP_MODE=warn
export CLAUDE_ROUTER_DISABLE=1
export CLAUDE_TOOL_SELECTOR_DISABLE=1
```

또는 settings.json에서 v6 후크 섹션을 주석 처리 (JSON은 주석 미지원이므로 백업 후 제거).

### Q7. rollback

```bash
# settings.json 복원
cp ~/.claude/settings.json.backup-* ~/.claude/settings.json

# 후크 파일 제거 (시나리오 B는 클론 디렉토리 삭제만)
rm -rf $CLAUDE_SKILL_DIR
```

---

## 10. 내 셋업 트리 구조 (한국어)

### 10-1. 레포 디렉토리 구조

```
claude_skill/                                    📦 Harness v6 메인 레포
│
├── 📄 README.md                                개요 + 9가지 개선 요약 + 인용 링크
├── 📄 SETUP_GUIDE_macOS.md                     이 문서 (맥북 적용 가이드)
├── 📄 SETUP_SCORE_2026-05.md                   점수 평가 (Before B+ → After A)
├── 📄 .gitignore                               trace/state 파일 제외
│
├── 📁 hooks/                                   🎯 후크 8개 (Claude Code 미들웨어)
│   ├── 🔧 prompt-cache-monitor.sh             [P0] 캐시 hit rate 추적
│   ├── 🔧 budget-gate.sh                       [P0] USD 누적 hard cap
│   ├── 🔧 llm-judge.sh                         [P1] Stop hook LLM-as-Judge (Spotify Honk)
│   ├── 🔧 tool-hash-dedup.sh                   [P1] Agent ping-pong 차단
│   ├── 🔧 model-router.sh                      [P1] 자동 모델 라우팅
│   ├── 🔧 tool-selector.sh                     [P1] MCP 카테고리 추천
│   ├── 🔧 otel-trace-exporter.sh               [P2] OTel GenAI 형식 변환
│   └── 🔧 bench-runner.sh                      [P2] Nightly self-benchmark
│
├── 📁 agents/                                  🤖 새 에이전트 1개 (24 → 25)
│   └── 📋 judge-agent.md                       [P2] Agent-as-a-Judge (5차원 rubric)
│
├── 📁 memory-schema/                           🧠 Memory v2 스키마 (Zep 패턴)
│   ├── 📄 README.md                            v2 frontmatter 스펙 + 마이그레이션
│   └── 📁 examples/                            예제 메모리
│       └── 📄 feedback-2026-05-14-budget-aware-coding.md
│
├── 📁 docs/                                    📚 (확장 예정)
│
├── 📁 settings/                                ⚙️ 설정 예제
│   └── 📄 settings.example.json                머지용 settings.json 템플릿
│
└── 📁 scripts/                                 🔨 유틸 스크립트
    └── 🔧 migrate-to-otel.sh                   기존 JSONL → OTel 일괄 변환
```

### 10-2. 적용 후 ~/.claude/ 디렉토리 (시나리오 B 기준)

```
~/.claude/                                       🏠 Claude Code 홈 디렉토리
│
├── 📄 settings.json                            ⚙️ 후크 등록 (v6 머지 후)
├── 📄 settings.json.backup-...                 백업 (적용 전)
├── 📄 .env                                     🔐 ANTHROPIC_API_KEY 보관
├── 📄 CLAUDE.md                                전역 지침 (기존)
│
├── 📁 hooks/                                   기존 후크 (보존됨)
│   └── (기존 v5 후크들...)
│
├── 📁 agents/                                  기존 24개 에이전트
│   └── (planner, code-reviewer, ... + judge-agent 심볼릭 링크 가능)
│
├── 📁 traces/                                  🆕 v6 후크 출력
│   ├── 📊 cache-metrics.jsonl                  prompt-cache-monitor
│   ├── ⚠️ cache-warnings.jsonl                 hit rate < 70%
│   ├── 💰 budget.jsonl                          budget-gate
│   ├── 🚨 llm-judge.jsonl                       llm-judge verdict
│   ├── 🔄 tool-dedup.jsonl                      tool-hash-dedup
│   ├── 🤖 model-router.jsonl                    model-router 추천
│   ├── 🛠️ tool-selector.jsonl                   tool-selector 추천
│   ├── 📡 otel-spans.jsonl                      OTel-format spans
│   └── 🎯 bench-results.jsonl                   self-bench 결과
│
├── 📁 budget-state/                            🆕 budget-gate 상태 (gitignore)
│   ├── session-<id>.txt                        세션별 누적 USD
│   └── daily-2026-05-14.txt                    날짜별 누적 USD
│
├── 📁 dedup-state/                             🆕 tool-hash-dedup 상태 (gitignore)
│   └── <session-id>.tsv                        세션별 hash counter
│
├── 📁 bench/                                   🆕 self-bench (선택)
│   ├── mini-tb/                                벤치 task 디렉토리
│   │   ├── task-001-.../                        README.md + verify.sh
│   │   └── task-002-.../
│   └── results/                                 일별 결과
│       └── 2026-05-14/
│
└── 📁 ...
```

### 10-3. 데이터 흐름 (다이어그램)

```
┌─────────────────────────────────────────────────────────────────┐
│                     사용자 입력 (Prompt)                          │
└──────────────────────────────┬──────────────────────────────────┘
                               ▼
              ┌────────────────────────────────┐
              │   UserPromptSubmit hook        │
              │   ├─ model-router.sh           │ → 모델 추천 컨텍스트 주입
              │   └─ tool-selector.sh          │ → MCP 카테고리 추천
              └──────────────┬─────────────────┘
                             ▼
              ┌────────────────────────────────┐
              │   PreToolUse hook              │
              │   └─ budget-gate.sh            │ → USD cap 체크 (block 가능)
              └──────────────┬─────────────────┘
                             ▼
                    ┌───────────────────┐
                    │   도구 실행         │
                    │   (Read/Edit/...)  │
                    └────────┬──────────┘
                             ▼
              ┌────────────────────────────────┐
              │   PostToolUse hook (async)     │
              │   ├─ tool-hash-dedup.sh        │ → ping-pong 감지
              │   └─ otel-trace-exporter.sh    │ → OTel JSONL 기록
              └──────────────┬─────────────────┘
                             ▼
                  ┌─────────────────────┐
                  │   세션 종료 (Stop)   │
                  └──────────┬──────────┘
                             ▼
              ┌────────────────────────────────┐
              │   Stop hook                    │
              │   ├─ llm-judge.sh              │ → Haiku에 평가 요청
              │   │   ├─ verdict: PASS         │
              │   │   ├─ verdict: BLOCK        │ → 차단
              │   │   └─ ... reason/concerns   │
              │   └─ prompt-cache-monitor.sh   │ → cache hit rate 집계
              └────────────────────────────────┘
                             ▼
                  ┌─────────────────────┐
                  │   세션 종료 완료     │
                  └─────────────────────┘

  병렬 실행 (cron):
  ┌─────────────────────────────────────┐
  │   매일 03:00 — bench-runner.sh      │ → Terminal Bench mini 20-task
  │                                     │   → bench-results.jsonl
  └─────────────────────────────────────┘
```

### 10-4. 환경변수 매핑

```
┌─────────────────────────────────────────────────────────────┐
│  ~/.zshrc 또는 ~/.bash_profile                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  CLAUDE_SKILL_DIR ─────────► settings.json의 ${...} 치환    │
│  ANTHROPIC_API_KEY ────────► llm-judge.sh (필수)            │
│                                                             │
│  CLAUDE_BUDGET_SESSION_USD ─► budget-gate.sh 세션 cap        │
│  CLAUDE_BUDGET_DAILY_USD ───► budget-gate.sh 일일 cap        │
│  CLAUDE_BUDGET_MODE ───────► block | warn                   │
│                                                             │
│  CLAUDE_JUDGE_MODE ────────► block | warn (초기 warn 권장)  │
│  CLAUDE_JUDGE_MODEL ───────► claude-haiku-4-5-20251001 기본 │
│  CLAUDE_JUDGE_DISABLE ─────► 1 = 비활성화                    │
│                                                             │
│  CLAUDE_DEDUP_THRESHOLD ───► tool-hash-dedup 임계치 (기본 5)│
│  CLAUDE_DEDUP_MODE ────────► block | warn                   │
│                                                             │
│  CLAUDE_ROUTER_DISABLE ────► model-router 비활성화           │
│  CLAUDE_TOOL_SELECTOR_DISABLE ─► tool-selector 비활성화      │
│                                                             │
│  CLAUDE_BENCH_TASKS ───────► bench task 디렉토리             │
│  CLAUDE_BENCH_MODEL ───────► bench 모델                      │
│  CLAUDE_BENCH_BUDGET ──────► task당 토큰 cap (기본 50000)   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 부록 — 자주 묻는 질문

**Q. 기존 ~/.claude/hooks/와 충돌하나요?**
A. 시나리오 B를 따르면 충돌하지 않습니다. settings.json에 절대경로로 등록하므로 별도 후크 셋업이 병행됩니다.

**Q. Claude Pro/Max 사용자도 prompt caching 효과를 보나요?**
A. 네, Claude API와 동일한 캐싱 정책이 적용됩니다. 다만 Pro/Max는 토큰 직접 청구 대신 사용량 한도로 계산되므로 비용 절감보다는 **latency 단축** + **한도 내 더 많은 작업** 효과가 큽니다.

**Q. Self-bench cron은 비용이 얼마나 들까요?**
A. 20-task × Sonnet 평균 비용 약 $0.10~$0.30 / task = 일 $2~$6. 한 달 $60~$180. 야간 진행이므로 작업 방해 없음. 필요 시 task 수 줄이거나 주 1회 실행으로 축소.

**Q. LLM Judge가 PR 머지를 자주 막으면 어떡하죠?**
A. `CLAUDE_JUDGE_MODE=warn` 으로 시작해 1~2주 관찰. JSONL 로그를 보고 false positive 패턴 파악 후 `llm-judge.sh`의 프롬프트를 프로젝트 맥락에 맞게 튜닝. 기본 프롬프트는 보수적으로 설정되어 있습니다.

**Q. 회사 보안 정책상 외부 API 호출이 금지인데 LLM Judge를 쓸 수 있나요?**
A. `CLAUDE_JUDGE_DISABLE=1` 로 비활성화 후 결정적 verification만 사용 (verification-loop.sh + test-coverage-gate.sh). Spotify Honk 25% veto 효과는 못 얻지만 다른 8개는 사용 가능.

---

## 다음 단계

- [SETUP_SCORE_2026-05.md](./SETUP_SCORE_2026-05.md) — 점수 평가 상세
- [README.md](./README.md) — 9가지 개선 항목별 WHY/WHAT/HOW
- [memory-schema/README.md](./memory-schema/README.md) — Memory v2 사용법
- 1차 출처 인용 링크는 [README.md 하단](./README.md#참고-자료-1차-출처) 참조

문제/개선 제안: [hyunseung-aicx/claude_skill issues](https://github.com/hyunseung-aicx/claude_skill/issues)
