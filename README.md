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
- Codex 라이브 config 마이그레이션/부트스트랩 (아래 [Codex config](#codex-config) 참고)
- `stow --restow codex zsh agents claude`
- 가능한 범위에서 누락된 런타임 도구 설치
- Codex, LazyCodex, Claude MCP, zsh, agents, 수동 secret smoke check

개인 secret은 의도적으로 동기화하지 않는다. 각 머신의 `~/.zsh_secrets`에 직접 둔다.

## Homebrew

Homebrew 설치 목록은 루트 `Brewfile`로 관리한다.

```bash
brew bundle dump --file=Brewfile --force --no-vscode --no-go --no-npm --no-describe
```

`sync.sh`는 자동 upgrade를 피하기 위해 `HOMEBREW_BUNDLE_NO_UPGRADE=1`과 `--no-upgrade`로 실행한다.
설치된 패키지를 Brewfile에 정확히 맞춰 지우는 `brew bundle cleanup --force`는 자동 실행하지 않는다.

## Codex config

`~/.codex/config.toml`(라이브 파일)은 git으로 추적하지 않는다. Codex가 프로젝트 trust,
훅 신뢰 해시, marketplace 타임스탬프 같은 머신 종속 상태를 이 파일에 계속 써넣기 때문이다
([openai/codex#14601](https://github.com/openai/codex/issues/14601) 참고). 대신 의도적
설정만 담은 `codex/.codex/config.template.toml`을 추적한다.

- 새 머신: `sync.sh`가 라이브 파일이 없으면 템플릿을 복사해준다.
- 설정을 의도적으로 바꿨다면 템플릿에도 반영한다. 차이 확인:

  ```bash
  scripts/codex-config-diff.sh
  ```

- 구 레이아웃(심링크) 머신에서 pull이 충돌하면, 라이브 내용을 백업 후 pull 하고 `sync.sh`를 실행한다:

  ```bash
  cd ~/.dotfiles
  cp codex/.codex/config.toml ~/.codex/config.live.bak
  git checkout -- codex/.codex/config.toml
  git pull --ff-only
  rm ~/.codex/config.toml   # dangling symlink
  mv ~/.codex/config.live.bak ~/.codex/config.toml
  ./sync.sh
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
bash -n sync.sh scripts/claude-mcp-sync.sh scripts/codex-config-diff.sh
zsh -n zsh/.zprofile zsh/.zshrc
shellcheck sync.sh scripts/claude-mcp-sync.sh scripts/codex-config-diff.sh
./sync.sh
```

`shellcheck`가 없으면 설치한다:

```bash
brew install shellcheck
```
