# ⚙️ settings/ — 후크를 자동차에 연결하는 설계도

> **한 줄 요약**: 후크들을 클로드 코드의 어느 이벤트에 연결할지 정의하는 설정 파일입니다.

---

## settings.json이 뭔가요?

`~/.claude/settings.json` 은 클로드 코드의 **전역 설정 파일**입니다. 여러 가지를 설정할 수 있지만 이 레포에서 가장 중요한 건 `hooks` 섹션입니다.

### 자동차 비유

ABS·에어백을 자동차에 달기만 해서는 작동하지 않습니다. **전선이 연결돼야** 합니다. settings.json이 그 전선 역할입니다.

후크 파일을 만들기만 해서는 클로드 코드가 인식하지 못합니다. settings.json에 **"어느 이벤트에 어느 후크를 부를지"** 명시해야 비로소 발동됩니다.

---

## 이벤트(Hook 이름) 종류

클로드 코드에는 약 27개 이벤트가 있습니다. 이 레포에서 사용하는 6개:

| 이벤트 | 언제 발생 | 이 레포에서 부르는 후크 |
|--------|---------|--------------------|
| `SessionStart` | 클로드 코드 세션 시작 시 | `prompt-cache-monitor.sh` |
| `UserPromptSubmit` | 사용자가 메시지 입력 시 | `model-router-v2.sh`, `tool-selector.sh` |
| `PreToolUse` | 도구 사용 직전 | `budget-gate.sh` |
| `PostToolUse` | 도구 사용 후 | `tool-hash-dedup.sh`, `otel-trace-exporter.sh`, `routing-accuracy-tracker.sh` |
| `Stop` | 작업 종료 시 | `llm-judge.sh`, `prompt-cache-monitor.sh` |

---

## `settings.example.json` — 바로 쓸 수 있는 예시

이 폴더의 `settings.example.json` 은 이 레포 후크 9개를 **모두 등록한 완성형 예시**입니다. 본인의 `~/.claude/settings.json` 에 머지(병합)하면 됩니다.

### 핵심 구조

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_SKILL_DIR}/hooks/llm-judge.sh",
            "timeout": 45
          }
        ]
      }
    ]
  }
}
```

해석:
- `Stop` 이벤트가 발생하면 (= 작업 종료 시)
- `${CLAUDE_SKILL_DIR}/hooks/llm-judge.sh` 를 실행하라
- 최대 45초까지 기다린다

`${CLAUDE_SKILL_DIR}` 는 환경변수로 치환됩니다 — 사용자가 어디에 레포를 클론했든 자동으로 그 경로가 들어갑니다.

---

## 머지 방법

상세는 [`../SETUP_GUIDE_macOS.md`](../SETUP_GUIDE_macOS.md) 6절 참조. 빠른 방법:

```bash
# 1. 기존 settings.json 백업
cp ~/.claude/settings.json ~/.claude/settings.json.backup-$(date +%Y%m%d)

# 2. envsubst 로 ${CLAUDE_SKILL_DIR} 치환하면서 새 파일 작성
envsubst < settings/settings.example.json > /tmp/new-settings.json

# 3. jq 로 기존 hooks와 머지
jq -s '
  .[0] as $existing | .[1] as $new |
  $existing * {
    "hooks": (
      ($existing.hooks // {}) as $eh |
      ($new.hooks // {}) as $nh |
      ($eh | keys + ($nh | keys)) | unique | map({
        (.): (($eh[.] // []) + ($nh[.] // []))
      }) | add
    )
  }
' ~/.claude/settings.json /tmp/new-settings.json > /tmp/merged-settings.json

# 4. 결과 확인 후 적용
diff ~/.claude/settings.json /tmp/merged-settings.json
mv /tmp/merged-settings.json ~/.claude/settings.json
```

---

## 검증

```bash
# JSON 문법 체크
jq . ~/.claude/settings.json > /dev/null && echo "✓ Valid" || echo "✗ Invalid"

# 등록된 후크 경로 확인
jq -r '.hooks | .. | .command? // empty' ~/.claude/settings.json | sort -u
```

모든 경로가 **절대 경로**여야 합니다 (`${...}` 가 남아있으면 미치환).

---

## 환경변수와의 관계

settings.json만 머지해도 작동하지만, **환경변수로 동작 조절** 가능합니다:

```bash
# ~/.zshrc 에 추가
export CLAUDE_SKILL_DIR="$HOME/claude_skill"
export ANTHROPIC_API_KEY="sk-ant-..."     # llm-judge.sh 필수
export CLAUDE_BUDGET_SESSION_USD=5         # budget-gate 세션 한도
export CLAUDE_BUDGET_DAILY_USD=20          # budget-gate 일일 한도
export CLAUDE_JUDGE_MODE=warn              # llm-judge 초기 모드
```

상세한 환경변수 목록은 `settings.example.json` 안의 `_env_vars_optional` 섹션 참조.

---

## 자주 묻는 질문

**Q. 기존 ~/.claude/settings.json의 후크와 충돌하나요?**
A. 같은 이벤트(예: `Stop`)에 여러 후크를 배열로 추가하므로 **공존 가능**합니다. 단, 같은 후크가 두 번 등록되지 않도록 머지 시 주의.

**Q. 모든 후크를 한 번에 활성화하기 부담스럽습니다.**
A. P0 후크부터 단계적으로 추가하세요:
1. 우선 `budget-gate.sh` 하나만 PreToolUse에 등록 → 1주 사용
2. 안정적이면 `prompt-cache-monitor.sh` 추가
3. 그 다음 P1, P2 순서

**Q. settings.local.json 도 사용하나요?**
A. 클로드 코드는 settings.json (전역) + settings.local.json (프로젝트별) 둘 다 읽습니다. 이 레포의 후크는 전역(settings.json)에 등록하는 게 일반적입니다.

**Q. 후크 비활성화하려면?**
A. settings.json에서 해당 후크 객체를 제거하거나, 환경변수로 끄세요 (`CLAUDE_JUDGE_DISABLE=1` 등).

---

## 더 깊이

- [`../SETUP_GUIDE_macOS.md`](../SETUP_GUIDE_macOS.md) 5~6절 — 환경변수 + 머지 단계별 가이드
- [`./settings.example.json`](./settings.example.json) — 완성형 설정 예시
- [Claude Code Hooks 공식 문서](https://code.claude.com/docs/en/hooks) — 27개 이벤트 전체
