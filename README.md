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

## Stow 패키지

주요 패키지:

```bash
stow codex zsh agents claude
```

`sync.sh`는 위 패키지를 `--restow`로 적용한다.

## 스크립트 검증

쉘 스크립트는 별도 테스트 프레임워크 대신 문법 검사, shellcheck, 실제 smoke run으로 검증한다:

```bash
bash -n sync.sh scripts/claude-mcp-sync.sh
zsh -n zsh/.zprofile zsh/.zshrc
shellcheck sync.sh scripts/claude-mcp-sync.sh
./sync.sh
```

`shellcheck`가 없으면 설치한다:

```bash
brew install shellcheck
```
