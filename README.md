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
- 명시적인 `$HOME` target으로 `codex`, `zsh`, `agents`, `claude`, `gcloud` Stow 패키지 동기화
- `~/.codex/AGENTS.md`와 `~/.claude/CLAUDE.md`를 공통 `~/.agents/AGENTS.md`에 연결
- `~/.agents/skills`를 정본으로 Claude user skill 심링크 동기화
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
stow --dir="$PWD" --target="$HOME" --restow agents
stow --dir="$PWD" --target="$HOME" --restow --no-folding codex claude gcloud zsh
```

`sync.sh`는 위 패키지를 같은 방식으로 적용한다. `agents`는 `~/.agents` 전체 링크를 허용하고,
런타임 상태가 함께 사는 `~/.codex`, `~/.claude`, `~/.local`은 `--no-folding`으로 실제 로컬
디렉터리를 유지한다. `--target="$HOME"`을 명시하므로 저장소를 홈 바로 아래가 아닌 곳에 clone해도
배포 위치는 동일하다.

사용자 스킬의 정본은 `~/.agents/skills`다. `sync.sh`는 각 스킬을 `~/.claude/skills`에 상대경로
심링크로 노출한다. 이미 존재하는 Claude 전용 파일이나 다른 대상을 가리키는 심링크는 덮어쓰지 않고, 이전
동기화가 만든 끊어진 심링크만 정리한다.

Skills CLI가 기록한 source와 folder hash는 `agents/.agents/.skill-lock.json`으로 함께 동기화한다.
upstream 업데이트를 확인·적용한 뒤 Claude 링크를 다시 정렬하려면 다음을 실행한다.

```bash
npx skills update --global --yes
./sync.sh
```

## Agent instructions

개인 전역 지침의 정본은 `agents/.agents/AGENTS.md`이며 Stow가 `~/.agents`로 노출한다.
`sync.sh`는 Git이 추적하는 심링크를 만들지 않고 각 머신에서 다음 상대 링크를 직접 관리한다.

```text
~/.codex/AGENTS.md  -> ../.agents/AGENTS.md
~/.claude/CLAUDE.md -> ../.agents/AGENTS.md
```

기존 일반 파일을 처음 마이그레이션할 때는 내용을 다음 파일에 보존한 뒤 링크를 만든다.

```text
~/.codex/AGENTS.md.before-dotfiles-sync.bak
~/.claude/CLAUDE.md.before-dotfiles-sync.bak
```

이미 다른 곳을 가리키는 링크나 같은 이름의 백업이 있으면 자동으로 덮어쓰지 않고 실패한다.
저장소 루트의 `AGENTS.md`는 이 dotfiles 저장소에만 적용되는 규칙이고, 루트 `CLAUDE.md`는
`@AGENTS.md`로 그 규칙을 가져온다.

## 스크립트 검증

쉘 스크립트는 별도 테스트 프레임워크 대신 문법 검사, shellcheck, 실제 smoke run으로 검증한다:

```bash
bash -n sync.sh scripts/claude-mcp-sync.sh scripts/codex-config-diff.sh \
  scripts/agent-instructions-sync.sh scripts/stow-sync.sh \
  scripts/test-agent-instructions-sync.sh scripts/test-stow-sync.sh \
  gcloud/bootstrap.sh gcloud/.local/bin/ga-report
zsh -n zsh/.zprofile zsh/.zshrc
shellcheck sync.sh scripts/claude-mcp-sync.sh scripts/codex-config-diff.sh \
  scripts/agent-instructions-sync.sh scripts/stow-sync.sh \
  scripts/test-agent-instructions-sync.sh scripts/test-stow-sync.sh \
  gcloud/bootstrap.sh gcloud/.local/bin/ga-report
bash scripts/test-stow-sync.sh
bash scripts/test-agent-instructions-sync.sh
scripts/codex-config-diff.sh
gcloud/bootstrap.sh --check
./sync.sh
```

`shellcheck`가 없으면 설치한다:

```bash
brew install shellcheck
```
