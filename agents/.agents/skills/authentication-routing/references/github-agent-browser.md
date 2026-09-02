# GitHub와 전용 agent-browser 프로필

## 기본 구성

GitHub 화면 조작이 필요한 작업에는 일반 Chrome 프로필과 분리된 persistent `agent-browser` 프로필을 사용한다.

- 프로필 경로: `~/.agent-browser/profiles/github-agent`
- 브라우저 세션 이름 예시: `github-independent`
- Chrome의 `dev-agent` 프로필과는 별개의 저장 공간이다.
- 이 프로필은 PC별 로컬 상태다. dotfiles, Git 저장소, 백업 파일에 복사하거나 커밋하지 않는다.

최초 설정은 headed 브라우저에서 사용자가 직접 한다.

```bash
agent-browser --session github-independent \
  --profile ~/.agent-browser/profiles/github-agent \
  --headed open https://github.com/login
```

사용자가 GitHub 로그인, 2FA, passkey, 조직 SSO를 완료한 뒤 GitHub 화면이 로그인 상태인지 확인한다. 비밀번호·OTP·복구 코드를 채팅이나 명령 인자로 받지 않는다. 이후 같은 `--profile`을 지정하면 브라우저가 재시작되어도 해당 프로필의 로그인 상태를 재사용할 수 있다.

## 작업별 선택

`gh auth status`로 이미 승인된 CLI 인증을 확인할 수 있다. PR·이슈·체크 상태처럼 구조화된 데이터만 필요하면 `gh` 또는 공식 GitHub 커넥터를 우선한다. 브라우저 프로필을 CLI 인증으로 변환하지 않는다.

다음 작업에는 전용 프로필을 사용한다.

- PR 본문에 before/after 이미지를 실제로 업로드해야 할 때
- GitHub에서 보이는 화면을 확인하거나 스크린샷을 남겨야 할 때
- 웹 UI의 렌더링·권한·상호작용을 검증해야 할 때

파일 업로드 후에는 PR 본문에서 이미지가 실제로 렌더링되는지, before/after 라벨과 순서가 맞는지 확인한다. 파일 경로만 본문에 남아 있는 상태를 성공으로 간주하지 않는다.

## 재인증과 사용자 개입

프로필에서 로그인 화면, 2FA, passkey, SSO, CAPTCHA, 계정 선택 또는 권한 승인 화면이 나오면 자동화가 멈춘 지점에서 사용자에게 화면 조작을 요청한다. 사용자가 완료했다고 알려주면 같은 프로필에서 작업을 재개한다.

다음 행동은 하지 않는다.

- 쿠키, local storage, IndexedDB, 세션 토큰, 인증 헤더, HAR, 프로필 디렉터리를 읽거나 출력한다.
- 브라우저 세션을 PAT·API token·Git credential로 변환한다.
- 로그인된 세션을 이용해 새 자격 증명이나 더 넓은 scope를 자동 발급한다.
- 프로필 상태를 `--restore`용 파일이나 다른 프로세스에 넘긴다.
- 로그인 문제를 해결하려고 다른 Chrome 프로필의 상태를 복사한다.

1Password credential provider나 기타 브라우저 플러그인은 기본 경로가 아니다. 별도로 설치·승인된 경우에도 vault 비밀번호나 secret 값을 명령 인자·로그로 전달하지 않고, 필요한 입력은 사용자가 공식 화면에서 처리한다.

## 사용자의 기존 Chrome을 붙여야 하는 경우

이미 열린 Chrome `dev-agent` 세션에 의존하는 작업은 사용자가 그 세션을 사용하라고 명시한 경우에만 수행한다. 이것은 전용 `agent-browser` 프로필을 재사용하는 것과 다른 경로다.

Chrome 원격 디버깅 연결에서 `Allow remote debugging` 대화가 반복되거나 자동 연결 endpoint가 맞지 않는 오류가 나오면 승인 대화를 무한히 재시도하지 않는다. 전용 프로필로 전환하거나, 사용자가 명시적으로 live attach를 요청하고 Chrome이 승인된 디버깅 endpoint를 제공하는 경우에만 그 연결을 진단한다. 작업 후 원격 디버깅을 계속 켜 둘 필요가 없으면 끈다.

## 참고 문서

- [agent-browser authentication](https://github.com/vercel-labs/agent-browser/blob/main/skill-data/core/references/authentication.md)
- [agent-browser security](https://agent-browser.dev/security)
