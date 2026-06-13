#!/usr/bin/env bash

set -u

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILURES=0
WARNINGS=0

pass() {
  printf 'PASS %s\n' "$1"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  printf 'WARN %s\n' "$1"
}

fail() {
  FAILURES=$((FAILURES + 1))
  printf 'FAIL %s\n' "$1"
}

section() {
  printf '\n## %s\n' "$1"
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

sync_git() {
  section 'Git'

  if ! has_command git; then
    fail 'git missing: install Xcode Command Line Tools or Homebrew git'
    return
  fi

  if [[ -n "$(git -C "$DOTFILES_DIR" status --short)" ]]; then
    warn 'dotfiles has local changes; skipped git pull'
    return
  fi

  if git -C "$DOTFILES_DIR" pull --ff-only; then
    pass 'dotfiles is up to date'
  else
    fail 'git pull --ff-only failed'
  fi
}

sync_stow() {
  section 'Stow'

  if ! has_command stow; then
    fail 'stow missing: brew install stow'
    return
  fi

  if (cd "$DOTFILES_DIR" && stow --restow codex zsh agents claude); then
    pass 'stow packages restowed: codex zsh agents claude'
  else
    fail 'stow --restow failed'
  fi
}

sync_slack_mcp_server() {
  section 'Slack MCP'

  if has_command slack-mcp-server; then
    pass "slack-mcp-server: $(command -v slack-mcp-server)"
    return
  fi

  if has_command go; then
    local go_bin
    go_bin="${GOBIN:-$(go env GOPATH)/bin}/slack-mcp-server"
    if [[ -x "$go_bin" ]]; then
      pass "slack-mcp-server: $go_bin"
      return
    fi

    if go install github.com/korotovsky/slack-mcp-server@latest; then
      pass 'slack-mcp-server installed'
    else
      warn 'slack-mcp-server install failed'
    fi
    return
  fi

  warn 'go missing; skipped slack-mcp-server install'
}

sync_lazycodex() {
  section 'LazyCodex'

  if ! has_command npx; then
    fail 'npx missing: install Node/npm first'
    return
  fi

  if has_command omo && [[ -d "$HOME/.codex/plugins/cache/sisyphuslabs/omo" ]]; then
    pass "omo: $(command -v omo)"
  else
    if npx lazycodex-ai install --no-tui; then
      pass 'LazyCodex installed'
    else
      fail 'npx lazycodex-ai install failed'
      return
    fi
  fi

  if npx lazycodex-ai doctor --status; then
    pass 'LazyCodex doctor completed'
  else
    warn 'LazyCodex doctor returned a warning status'
  fi
}

sync_claude() {
  section 'Claude'

  if ! has_command claude; then
    warn 'claude missing; skipped Claude MCP sync'
    return
  fi

  if bash "$DOTFILES_DIR/scripts/claude-mcp-sync.sh"; then
    pass 'Claude MCP synced'
  else
    warn 'Claude MCP sync failed'
  fi
}

check_command() {
  local command_name="$1"
  local install_hint="$2"

  if has_command "$command_name"; then
    pass "$command_name: $(command -v "$command_name")"
  else
    fail "$command_name missing: $install_hint"
  fi
}

check_symlink() {
  local link_path="$1"
  local expected_target="$2"

  if [[ ! -L "$link_path" ]]; then
    fail "$link_path is not a symlink"
    return
  fi

  local actual_target
  actual_target="$(readlink "$link_path")"
  if [[ "$actual_target" == "$expected_target" ]]; then
    pass "$link_path -> $actual_target"
  else
    fail "$link_path points to $actual_target, expected $expected_target"
  fi
}

check_secret_name() {
  local file_path="$1"
  local name="$2"

  if [[ ! -f "$file_path" ]]; then
    fail "$file_path missing"
    return
  fi

  if grep -Eq "^[[:space:]]*(export[[:space:]]+)?${name}=" "$file_path"; then
    pass "$name present in $file_path"
  else
    warn "$name not found in $file_path"
  fi
}

run_smoke_checks() {
  section 'Smoke checks'

  check_command zsh 'Use macOS zsh or install zsh.'
  check_command node 'Install Node via fnm, nvm, or Homebrew.'
  check_command npx 'Install Node/npm.'
  check_command codex 'Install Codex CLI/App first.'
  check_command python3 'brew install python'

  check_symlink "$HOME/.codex/config.toml" "../.dotfiles/codex/.codex/config.toml"
  check_symlink "$HOME/.codex/hooks.json" "../.dotfiles/codex/.codex/hooks.json"
  check_symlink "$HOME/.codex/agents" "../.dotfiles/codex/.codex/agents"
  check_symlink "$HOME/.agents/skills" "../.dotfiles/agents/.agents/skills"
  check_symlink "$HOME/.agents/.skill-lock.json" "../.dotfiles/agents/.agents/.skill-lock.json"
  check_symlink "$HOME/.zshrc" ".dotfiles/zsh/.zshrc"
  check_symlink "$HOME/.zprofile" ".dotfiles/zsh/.zprofile"

  if python3 -c 'import tomllib' >/dev/null 2>&1; then
    pass 'python3 tomllib available'
  else
    fail 'python3 tomllib missing; use Python 3.11+ from Homebrew and restart shell'
  fi

  if zsh -n "$HOME/.zshrc" && zsh -n "$HOME/.zprofile"; then
    pass 'zsh config syntax valid'
  else
    fail 'zsh config syntax failed'
  fi

  if has_command shellcheck; then
    if shellcheck "$DOTFILES_DIR/sync.sh" "$DOTFILES_DIR/scripts/claude-mcp-sync.sh"; then
      pass 'shellcheck passed'
    else
      fail 'shellcheck failed'
    fi
  else
    warn 'shellcheck missing: brew install shellcheck'
  fi

  check_secret_name "$HOME/.zsh_secrets" GITHUB_MCP_PAT
  if grep -Eq '^[[:space:]]*(export[[:space:]]+)?SLACK_MCP_(XOXP|XOXB)_TOKEN=' "$HOME/.zsh_secrets" 2>/dev/null; then
    pass 'Slack MCP token present in ~/.zsh_secrets'
  else
    warn 'Slack MCP token not found in ~/.zsh_secrets'
  fi

  if has_command codex; then
    local codex_mcp_list
    codex_mcp_list="$(codex mcp list 2>&1)"
    printf '%s\n' "$codex_mcp_list" | grep -E '(^|[[:space:]])(ast_grep|lsp|git_bash)([[:space:]]|$)' || true
    if printf '%s\n' "$codex_mcp_list" | grep -Eq '(^|[[:space:]])ast_grep([[:space:]]|$)' &&
      printf '%s\n' "$codex_mcp_list" | grep -Eq '(^|[[:space:]])lsp([[:space:]]|$)'; then
      pass 'OMO MCP tools visible in Codex'
    else
      fail 'OMO MCP tools not visible; restart Codex or rerun npx lazycodex-ai install'
    fi
  fi
}

printf 'dotfiles: %s\n' "$DOTFILES_DIR"

sync_git
sync_stow
sync_slack_mcp_server
sync_lazycodex
sync_claude
run_smoke_checks

section 'Summary'
printf 'Failures: %s, warnings: %s\n' "$FAILURES" "$WARNINGS"

if [[ $FAILURES -gt 0 ]]; then
  exit 1
fi
