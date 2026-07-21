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

sync_codex_config() {
  section 'Codex config'

  local live="$HOME/.codex/config.toml"
  local template="$DOTFILES_DIR/codex/.codex/config.template.toml"

  if [[ ! -f "$template" ]]; then
    fail "config template missing: $template"
    return
  fi

  mkdir -p "$HOME/.codex"

  if [[ -L "$live" ]]; then
    if [[ -e "$live" ]]; then
      # Old layout: symlink into the repo. Detach it, keeping current content.
      local tmp
      tmp="$(mktemp)"
      cat "$live" >"$tmp"
      rm "$live"
      mv "$tmp" "$live"
      pass 'live config detached from repo symlink (content preserved)'
    else
      # Dangling symlink: repo copy was removed by git pull before migration ran.
      rm "$live"
      cp "$template" "$live"
      warn 'dangling config symlink replaced from template; re-approve hooks/projects in Codex'
    fi
    return
  fi

  if [[ ! -f "$live" ]]; then
    cp "$template" "$live"
    pass 'live config bootstrapped from template'
    return
  fi

  pass 'live config is a machine-local file'
}

sync_stow() {
  section 'Stow'

  if ! has_command stow; then
    fail 'stow missing: brew install stow'
    return
  fi

  if (cd "$DOTFILES_DIR" && stow --restow codex zsh agents claude gcloud); then
    pass 'stow packages restowed: codex zsh agents claude gcloud'
  else
    fail 'stow --restow failed'
  fi
}

# ~/.claude/settings.json is NOT stow-symlinked: Orca (the multi-agent cockpit)
# injects runtime `hooks` into it at launch, which would pollute the repo or
# break a symlink. Instead the repo holds the canonical base; here we merge the
# base into the machine-local live file while preserving Orca's runtime keys.
sync_claude_settings() {
  section 'Claude settings'

  local base="$DOTFILES_DIR/claude/.claude/settings.json"
  local live="$HOME/.claude/settings.json"

  if [[ ! -f "$base" ]]; then
    fail "claude settings base missing: $base"
    return
  fi

  if ! has_command jq; then
    fail 'jq missing: brew install jq (needed to merge claude settings)'
    return
  fi

  mkdir -p "$HOME/.claude"

  # Fresh machine: seed from base; Orca injects its hooks on next launch.
  if [[ ! -f "$live" ]]; then
    cp "$base" "$live"
    pass 'claude settings bootstrapped from base'
    return
  fi

  # Old layout: live was a repo symlink. Detach to a machine-local file so Orca
  # can inject without writing through into the repo.
  if [[ -L "$live" ]]; then
    local detached
    detached="$(mktemp)"
    cat "$live" >"$detached"
    rm "$live"
    mv "$detached" "$live"
    warn 'claude settings detached from repo symlink (now machine-local)'
  fi

  # Merge: base is authoritative for the keys it defines; jq `*` deep-merges
  # objects (base wins) and replaces arrays wholesale (intended for the
  # permission/allowlist arrays). Runtime/machine-local keys are preserved from
  # live: `hooks` (Orca/cmux inject these each launch) and `model` (per-session
  # choice). base.model still serves as the fresh-machine default via the cp path
  # above; on an existing machine the live value wins. The explicit re-assigns
  # also keep live's values even if these keys are added to base by mistake.
  local merged
  merged="$(mktemp)"
  if ! jq -s '
        .[0] as $live | .[1] as $base
        | ($live * $base)
        | if $live.hooks then .hooks = $live.hooks else . end
        | if $live.model then .model = $live.model else . end
      ' "$live" "$base" >"$merged" 2>/dev/null || [[ ! -s "$merged" ]]; then
    rm -f "$merged"
    fail 'claude settings merge failed (invalid JSON in base or live?)'
    return
  fi

  # Only rewrite on a semantic change, to avoid reformatting churn that would
  # fight Orca's own writes. Compare canonicalized (sorted-key) forms via temp
  # files rather than process substitution, so this works in restricted shells.
  local live_canon merged_canon
  live_canon="$(mktemp)"
  merged_canon="$(mktemp)"
  jq -S . "$live" >"$live_canon" 2>/dev/null
  jq -S . "$merged" >"$merged_canon" 2>/dev/null
  if cmp -s "$live_canon" "$merged_canon"; then
    rm -f "$merged" "$live_canon" "$merged_canon"
    pass 'claude settings already in sync'
  else
    rm -f "$live_canon" "$merged_canon"
    mv "$merged" "$live"
    pass 'claude settings: base merged (orca hooks preserved)'
  fi
}

sync_homebrew() {
  section 'Homebrew'

  if ! has_command brew; then
    fail 'brew missing: install Homebrew first'
    return
  fi

  if HOMEBREW_BUNDLE_NO_UPGRADE=1 brew bundle check --file="$DOTFILES_DIR/Brewfile"; then
    pass 'Brewfile dependencies are satisfied'
    return
  fi

  if HOMEBREW_BUNDLE_NO_UPGRADE=1 brew bundle install --file="$DOTFILES_DIR/Brewfile" --no-upgrade; then
    pass 'Brewfile dependencies installed'
  else
    fail 'brew bundle install failed'
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

  if [[ -f "$HOME/.codex/config.toml" && ! -L "$HOME/.codex/config.toml" ]]; then
    pass "$HOME/.codex/config.toml is a machine-local file"
  else
    fail "$HOME/.codex/config.toml should be a regular file, not a symlink (rerun sync.sh)"
  fi

  if [[ -f "$HOME/.claude/settings.json" && ! -L "$HOME/.claude/settings.json" ]]; then
    if ! has_command jq || jq -e . "$HOME/.claude/settings.json" >/dev/null 2>&1; then
      pass "$HOME/.claude/settings.json is a machine-local file"
    else
      fail "$HOME/.claude/settings.json is invalid JSON"
    fi
  else
    fail "$HOME/.claude/settings.json should be a regular file, not a symlink (rerun sync.sh)"
  fi
  check_symlink "$HOME/.codex/config.template.toml" "../.dotfiles/codex/.codex/config.template.toml"
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

  if bash "$DOTFILES_DIR/scripts/codex-config-diff.sh" >/dev/null 2>&1; then
    pass 'codex config matches template'
  else
    warn 'codex config drifted from template; run scripts/codex-config-diff.sh'
  fi

  if has_command shellcheck; then
    if shellcheck "$DOTFILES_DIR/sync.sh" "$DOTFILES_DIR/scripts/claude-mcp-sync.sh" "$DOTFILES_DIR/scripts/codex-config-diff.sh"; then
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
sync_homebrew
sync_codex_config
sync_stow
sync_claude_settings
sync_slack_mcp_server
sync_lazycodex
sync_claude
run_smoke_checks

section 'Summary'
printf 'Failures: %s, warnings: %s\n' "$FAILURES" "$WARNINGS"

if [[ $FAILURES -gt 0 ]]; then
  exit 1
fi
