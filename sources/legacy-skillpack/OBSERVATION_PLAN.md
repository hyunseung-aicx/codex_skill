# 관찰 기반 후속 작업 계획 — 2026-04-23

> v10 권장안 완료(907 / A+) 후 설정된 **관찰 기간 2개 + KPI**.
> 섣불리 더 추가하지 않고, **사용 관찰 후 감산·조정**이 시니어 방식.

---

## 계획 1 — 6개월 사용 관찰 후 감산 (due: 2026-10-23)

### 목적
*"감산이 진정한 시니어"* — Anthropic best practice: *"If Claude already does
something correctly without the instruction, delete it or convert it to a hook."*

### 측정 방법

```bash
# 1. 훅 실호출 빈도 집계
for f in ~/.claude/traces/*.jsonl; do
  grep -oE '"event":"[^"]+"' "$f" | sort | uniq -c
done | sort -rn

# 2. 커맨드 실호출 빈도 (history.jsonl에서 /command 추출)
grep -oE '^/[a-z-]+' ~/.claude/history.jsonl | sort | uniq -c | sort -rn

# 3. skill 자동 발동 빈도 (learned/ 증가 추이)
```

### 감산 기준 (6개월 후 적용)
- **훅**: 호출 수 0회 → 제거 (또는 archive로)
- **커맨드**: 사용자 호출 0회 → 제거
- **스킬**: 자동/수동 발동 0회 → archive
- **룰**: 6개월간 referenced 0회 → 간소화

### 예상 감산 후보 (현재 시점 선제 의심)
- `commands/evolve.md`, `commands/setup-pm.md`, `commands/tool-registry.md`
- `agents/vector-db-agent.md` (실 프로젝트 없을 시)
- `skills/agent-evaluator`, `skills/industry-persona-qa` (명백히 특수 목적)

### 기대 효과
- Commands 33 → 20 → score_commands 88 → 80 (**하락**이지만 산식 상 "과잉 경고" 해소)
- 실제로는 **신뢰도 상승** — 남은 모든 자원이 실 사용 검증됨

### 체크포인트
- [ ] 2026-07-23 (3개월): 중간 집계 + 0회 호출 항목 목록화
- [ ] 2026-10-23 (6개월): 최종 감산 + `CHANGELOG` v11 기록

---

## 계획 2 — memory-writer 1주 가동 후 활성도 재측정 (due: 2026-04-30)

### 목적
v9의 `hooks/memory-writer.sh`(Stop 시 자동 MEMORY append)가 실제로 동작하는지
+ 관점 B(활성도) 점수가 자연 상승하는지 검증.

### 측정 방법

```bash
# 1. memory-writer 실 호출 확인
wc -l ~/.claude/traces/memory-writes.jsonl

# 2. 각 프로젝트 MEMORY.md 크기
for mem in ~/.claude/projects/*/memory/MEMORY.md; do
  echo "$(wc -l < "$mem" 2>/dev/null || echo 0) $mem"
done

# 3. 관점 B 점수 재측정 (SETUP_SCORE_2026-04.md 기준)
```

### 1주 후 KPI
- [ ] memory-writes.jsonl ≥ 5 entries (주 5일 이상 사용)
- [ ] 최소 1개 프로젝트 MEMORY.md ≥ 10 lines
- [ ] 관점 B 360 → 500+

### 1개월 후 KPI
- [ ] 모든 active 프로젝트 MEMORY.md 존재 (5/5)
- [ ] 관점 B 500 → 700+
- [ ] 종합 점수 688 → 780+ (A−)

### 검증 트리거
```bash
# 7일 후 간단 점검 스크립트
cd ~/Desktop/claude\ skill/My_ClaudeCode_Skill
bash scripts/score-setup.sh  # 현재 구조 점수
find ~/.claude/projects -name "MEMORY.md" -exec wc -l {} \;  # 활성도 raw
```

### 리스크
- memory-writer가 git 외 환경(노트북, 메모 앱 등)에선 동작 안 함
- 사용자가 세션을 Stop으로 종료하지 않고 창 닫기만 하면 hook 미발동
  → 발견 시 session-end 이벤트와 bind 고려

---

## 계획 3 — 다음 세션들에서 실제 사용 시그널 수집

이번 세션의 v8·v8.1·v9·v10은 **구조 셋업**. 진짜 가치는 다음 100시간 사용에서
드러남. 각 프로젝트 세션마다:

| 관찰 포인트 | 기록 위치 |
|------------|----------|
| `/spec` 실제 발동했는가? | memory-writer 자동 기록 |
| `/debug`으로 5단 분해 도움 받았는가? | MEMORY.md에 1줄 |
| context-guard 15회 경고 본 적 있는가? | traces/ 확인 |
| spec-gate가 실제 block한 적 있는가? | traces/ 확인 |
| failure-explainer가 3회+ escalation 뜬 적 있는가? | traces/ 확인 |

**이 중 2개 이상이 "한 번도 안 발동" → 해당 자원 실용성 의심, 감산 후보**

---

## 다음 스냅샷: 2026-07-23

3개월 후 이 문서를 다시 열어:
1. 각 KPI 현재 상태 기록
2. 계획 1, 2, 3의 달성률 수치화
3. v11 로드맵 (감산 기반)을 확정
