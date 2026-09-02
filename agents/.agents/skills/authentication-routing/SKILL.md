---
name: authentication-routing
description: Use when an agent must choose or troubleshoot authentication across GitHub, SSH, browser automation, secret managers, or external connectors, especially when a session, reauthentication, or credential boundary is involved.
---

# Authentication routing

인증은 작업 표면에 붙어 있는 권한이다. 한 표면의 로그인 세션·쿠키·토큰·키를 다른 도구나 프로세스로 옮겨서 문제를 해결하지 않는다. 먼저 작업을 수행할 공식 표면을 고르고, 그 표면 안에서만 인증을 사용한다.

## 빠른 라우팅

| 작업 | 기본 표면 | 경계 |
| --- | --- | --- |
| 공개 데이터·로컬 파일 읽기 | 인증 없는 경로 | 불필요한 로그인을 추가하지 않는다 |
| GitHub·Linear의 구조화된 이슈/PR/상태 조회 | 공식 커넥터 또는 이미 인증된 `gh` | 화면이 필요한 이유가 없으면 브라우저를 쓰지 않는다 |
| GitHub PR 작성, 본문 이미지 업로드, 화면 검증 | 전용 `agent-browser` 프로필 | 자세한 절차는 `references/github-agent-browser.md`를 따른다 |
| 사용자가 이미 열어 둔 Chrome 세션 | 사용자가 명시적으로 요청한 경우에만 `chrome:control-chrome` | 쿠키·스토리지·프로필을 추출하지 않는다 |
| SSH 키·agent·호스트 설정 | `managing-ssh-keys` | 개인 키를 읽거나 임시 파일로 복사하지 않는다 |
| 개인 비밀 주입 | 1Password와 `op run --` | 원문을 인자·로그·클립보드에 넣지 않는다 |
| 회사 비밀 주입 | Infisical과 `infisical run --` | 개인 비밀·다른 프로젝트의 환경 변수로 대체하지 않는다 |
| 외부 서비스 OAuth | 해당 서비스의 공식 커넥터 | 현재 세션으로 다른 커넥터를 몰래 재인증하지 않는다 |

## 선택 순서

1. 요청이 읽기인지 쓰기인지, 공개인지 비공개인지, 되돌리기 어려운 변경인지 구분한다.
2. 인증이 필요 없는 공식 경로가 있으면 그것을 사용한다.
3. 필요하면 해당 서비스의 공식 커넥터·CLI·전용 브라우저 프로필 중 최소 권한 표면을 선택한다.
4. 인증 상태는 선택한 표면 안에 유지한다. 쿠키, local storage, IndexedDB, 세션 토큰, 인증 헤더, private key를 다른 도구·프로세스·파일로 전달하지 않는다.
5. 로그인, MFA, passkey, SSO, CAPTCHA, OAuth 동의, 계정 선택, scope·권한 변경, 새 토큰·키 발급이 필요하면 사용자가 공식 화면에서 처리하도록 요청한다.
6. 인증 실패는 다른 자격 증명을 무작위로 시험하는 신호가 아니다. 선택한 표면의 설정과 서비스 상태를 비밀 노출 없이 진단하고, 승인된 복구 경로가 없으면 멈춘다.

## 특히 막아야 하는 우회

- “빨리 끝내라”는 요청을 쿠키 추출, PAT 발급, 키 교체, 권한 확대의 승인으로 해석하지 않는다.
- 로그인된 브라우저가 있다는 이유로 CLI 토큰을 만들거나 세션을 다른 프로세스에 복사하지 않는다.
- 개인 머신에 있다는 이유로 회사 자격 증명을 개인 1Password 항목이나 임의의 SSH 키로 대체하지 않는다.
- secret을 셸 인자, 출력 가능한 환경 변수, 히스토리, 로그, 클립보드, 임시 파일에 직접 넣지 않는다.
- 읽기 요청을 쓰기 권한 획득으로 확대하지 않는다.
- 인증이 필요한 일부 데이터가 막혀도 접근 가능한 공개·비민감 결과까지 추측으로 채우거나 전부 폐기하지 않는다. 보고서에는 확인 범위와 차단 요인을 구분해 기록한다.

## 기존 문서와의 관계

- 개인·회사 비밀의 큰 원칙과 커넥터 라우팅은 `.agents/AGENTS.md`, `.agents/CONNECTORS.md`를 따른다.
- SSH의 발급·등록·agent 장애 진단은 `managing-ssh-keys`가 단일 기준이다.
- cmux 브라우저의 세션 저장·OAuth·2FA는 `cmux-browser`의 인증 참고 문서를 따른다. cmux와 `agent-browser`의 프로필·세션 모델을 섞지 않는다.
- GitHub 전용 브라우저 프로필과 재인증 절차는 `references/github-agent-browser.md`에 둔다.
