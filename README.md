# Dotfiles

GNU Stow로 관리하는 개인 dotfiles.

## 머신 동기화

새 PC든 기존 PC든 같은 명령을 실행한다:

```bash
cd ~/.dotfiles
./sync.sh
```

`sync.sh`가 하는 일:

- worktree가 깨끗하면 `git pull --ff-only`
- `Brewfile` 기준 Homebrew formula/cask/tap 동기화
- Codex portable config를 라이브 파일에 병합하고 머신 상태 보존
- Codex 공식 plugin 설치 상태 동기화
- `stow --restow codex zsh agents claude`
- 가능한 범위에서 누락된 런타임 도구 설치
- Claude user MCP 동기화
- Google CLI + 기본/GA/BQ ADC 상태 검사(누락 시 브라우저 bootstrap 선택)
- Codex, Claude MCP, zsh, agents, 수동 secret smoke check

개인 secret과 인증 세션은 의도적으로 동기화하지 않는다. 각 머신의
`~/.zsh_secrets`, Google ADC, Codex/Claude 로그인과 connector OAuth는 로컬에서 만든다.
새 PC의 첫 실행이 Codex/Claude 설치만 마치고 로그인 경고를 남기면 두 앱에 로그인한 뒤
`./sync.sh`를 한 번 더 실행한다. 두 번째 실행은 idempotent하다.

## Homebrew

Homebrew 설치 목록은 루트 `Brewfile`로 관리한다.

```bash
brew bundle dump --file=Brewfile --force --no-vscode --no-go --no-npm --no-describe
```

`sync.sh`는 자동 upgrade를 피하기 위해 `HOMEBREW_BUNDLE_NO_UPGRADE=1`과 `--no-upgrade`로 실행한다.
설치된 패키지를 Brewfile에 정확히 맞춰 지우는 `brew bundle cleanup --force`는 자동 실행하지 않는다.

## Codex config

`~/.codex/config.toml`(라이브 파일)은 git으로 추적하지 않는다. Codex가 프로젝트 trust,
로컬 marketplace, 앱이 관리하는 MCP, notification 경로 같은 머신 종속 상태를 이 파일에
계속 쓴다. 대신 의도적 설정만 담은 `codex/.codex/config.template.toml`을 추적한다.

- 새 머신: `sync.sh`가 템플릿으로 라이브 파일을 만든다.
- 기존 머신: `scripts/codex-config-sync.py`가 portable 설정을 템플릿과 일치시키면서
  project trust, app-managed `node_repl`/Computer Use, 로컬 marketplace, notice/notify를 보존한다.
- 변경 전 라이브 파일은 `~/.codex/config.toml.before-dotfiles-sync.bak`에 백업한다.
- 설정을 의도적으로 바꿨다면 템플릿에 반영한 뒤 `./sync.sh`를 실행한다. 차이 확인:

  ```bash
  scripts/codex-config-diff.sh
  ```

- `sync.sh`는 다음 CLI-addressable 공식 plugin을 idempotent하게 설치한다:
  `slack`, `github`, `linear`, `notion`, `posthog` (`openai-curated`).
- Context7/Klaviyo connector app과 connector OAuth는 Codex 계정/앱에서 확인한다.
  인증 토큰이나 plugin cache는 Git으로 복사하지 않는다. 설치 후 Codex 새 세션을 시작한다.

- 구 레이아웃에서 `~/.codex/config.toml`이 repo 심링크인 경우에도 `sync.sh`가 내용을
  보존한 머신 로컬 파일로 분리한 뒤 새 템플릿을 병합한다.

## MCP / 인증 동기화 경계

| 대상 | dotfiles가 동기화 | 각 PC에서 다시 해야 함 |
| --- | --- | --- |
| Codex user config | model/sandbox/web/plugin enable/user MCP | Codex 로그인, connector OAuth, project trust |
| Codex plugins | 공식 plugin 설치 명령과 enable 상태 | 계정/관리자 정책에 따른 connector 연결 |
| Claude user MCP | GitHub, Context7, Playwright, PostHog 등록 | HTTP OAuth/토큰 환경변수 |
| Repo MCP | 각 repo의 `.codex/config.toml`, `.mcp.json`을 Git이 동기화 | Claude project MCP 최초 승인 |
| Google auth | keyless bootstrap 절차와 검증 | Ethan 브라우저 로그인 및 로컬 ADC 생성 |

Google credential 최종 구조와 새 머신 절차는 `gcloud/README.md`를 따른다. dotfiles는
credential JSON 자체를 운반하지 않고 다음 구조를 각 PC에서 재생성한다.

```text
application_default_credentials.json -> ethan@maycoders.com
adc-ga-reader.json                    -> Ethan -> ga-reader
adc-bq-reader.json                    -> Ethan -> bq-reader
```

## Stow 패키지

주요 패키지:

```bash
stow codex zsh agents claude
```

`sync.sh`는 위 패키지를 `--restow`로 적용한다.

## 스크립트 검증

쉘 스크립트는 별도 테스트 프레임워크 대신 문법 검사, shellcheck, 실제 smoke run으로 검증한다:

```bash
bash -n sync.sh scripts/claude-mcp-sync.sh scripts/codex-config-diff.sh \
  gcloud/bootstrap.sh gcloud/.local/bin/ga-report
zsh -n zsh/.zprofile zsh/.zshrc
shellcheck sync.sh scripts/claude-mcp-sync.sh scripts/codex-config-diff.sh \
  gcloud/bootstrap.sh gcloud/.local/bin/ga-report
scripts/codex-config-diff.sh
gcloud/bootstrap.sh --check
./sync.sh
```

`shellcheck`가 없으면 설치한다:

```bash
brew install shellcheck
```
