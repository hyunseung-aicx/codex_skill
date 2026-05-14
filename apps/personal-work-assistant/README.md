# Personal Work Assistant

개인용 AICX 업무 관제 로컬 플랫폼입니다. Jira, Confluence, GitHub를 한 화면에서 묶어 보고, 활성 스프린트/내 담당 티켓/관련 문서/PR 맥락을 빠르게 확인하는 목적입니다.

## 구조

- `server.js`: 로컬 Node 서버. Jira/Confluence/GitHub API 호출을 서버에서 처리합니다.
- `public/`: 브라우저 UI. 토큰은 브라우저로 내려보내지 않습니다.
- `.env.example`: 필요한 연결 값 예시입니다.

## 실행

```bash
cd $HOME/Desktop/aicx-repos/personal-work-assistant
cp .env.example .env
```

`.env`에 실제 값을 넣은 뒤:

```bash
node server.js
```

브라우저에서 `http://127.0.0.1:4173`으로 접속합니다.

## 필요한 권한

- Atlassian API token: Jira/Confluence 조회
- GitHub token: `aicx-kr` organization의 PR/커밋 검색
- Jira 프로젝트 권한: `AICC`
- Confluence 조회 권한: AICC/TECH 등 관련 스페이스

## 기본 사용 흐름

1. 대시보드에서 내 담당 활성 스프린트 티켓을 확인합니다.
2. 티켓을 클릭해 부모 에픽, 담당자, 상태, 우선순위, 스프린트를 봅니다.
3. 관련 Confluence 문서와 GitHub PR을 함께 확인합니다.
4. 누락 체크리스트로 Description, 담당자, 스프린트, 연결 PR 여부를 점검합니다.

## 보안 원칙

- 토큰은 `.env`에만 둡니다.
- `.env`는 Git에 커밋하지 않습니다.
- 서버는 기본적으로 `127.0.0.1`에서만 띄웁니다.
