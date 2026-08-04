#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC_SCRIPT="$DOTFILES_DIR/scripts/stow-sync.sh"
TEST_ROOT="$(mktemp -d /tmp/dotfiles-stow-sync-test.XXXXXX)"
TARGET_HOME="$TEST_ROOT/clone-parent/home"
LOCAL_AGENTS_HOME="$TEST_ROOT/local-agents-home"
STATUS_BEFORE="$(git -C "$DOTFILES_DIR" status --short --untracked-files=all)"

clean_test_root() {
  case "$TEST_ROOT" in
    /tmp/dotfiles-stow-sync-test.*)
      find "$TEST_ROOT" -depth -delete
      ;;
    *)
      printf 'FAIL refusing to clean unexpected path: %s\n' "$TEST_ROOT" >&2
      return 1
      ;;
  esac
}

assert_realpath_equals() {
  local actual_path="$1"
  local expected_path="$2"

  if [[ "$(realpath "$actual_path")" != "$(realpath "$expected_path")" ]]; then
    printf 'FAIL %s does not resolve to %s\n' "$actual_path" "$expected_path" >&2
    return 1
  fi
}

trap clean_test_root EXIT
mkdir -p "$TARGET_HOME"

bash "$SYNC_SCRIPT" "$DOTFILES_DIR" "$TARGET_HOME"
bash "$SYNC_SCRIPT" "$DOTFILES_DIR" "$TARGET_HOME"

mkdir -p "$LOCAL_AGENTS_HOME/.agents"
touch "$LOCAL_AGENTS_HOME/.agents/machine-local-sentinel"
bash "$SYNC_SCRIPT" "$DOTFILES_DIR" "$LOCAL_AGENTS_HOME"
bash "$SYNC_SCRIPT" "$DOTFILES_DIR" "$LOCAL_AGENTS_HOME"

[[ -L "$TARGET_HOME/.agents" ]]
assert_realpath_equals "$TARGET_HOME/.agents" "$DOTFILES_DIR/agents/.agents"

[[ -d "$LOCAL_AGENTS_HOME/.agents" && ! -L "$LOCAL_AGENTS_HOME/.agents" ]]
[[ -f "$LOCAL_AGENTS_HOME/.agents/machine-local-sentinel" ]]
assert_realpath_equals \
  "$LOCAL_AGENTS_HOME/.agents/AGENTS.md" \
  "$DOTFILES_DIR/agents/.agents/AGENTS.md"

for local_directory in "$TARGET_HOME/.codex" "$TARGET_HOME/.claude" "$TARGET_HOME/.local"; do
  [[ -d "$local_directory" && ! -L "$local_directory" ]]
done

[[ ! -e "$TARGET_HOME/.claude/settings.json" ]]
assert_realpath_equals \
  "$TARGET_HOME/.codex/config.template.toml" \
  "$DOTFILES_DIR/codex/.codex/config.template.toml"
assert_realpath_equals \
  "$TARGET_HOME/.codex/hooks.json" \
  "$DOTFILES_DIR/codex/.codex/hooks.json"
assert_realpath_equals \
  "$TARGET_HOME/.local/bin/ga-report" \
  "$DOTFILES_DIR/gcloud/.local/bin/ga-report"

STATUS_AFTER="$(git -C "$DOTFILES_DIR" status --short --untracked-files=all)"
if [[ "$STATUS_AFTER" != "$STATUS_BEFORE" ]]; then
  printf 'FAIL stow sync changed the dotfiles worktree\n' >&2
  diff <(printf '%s\n' "$STATUS_BEFORE") <(printf '%s\n' "$STATUS_AFTER") >&2 || true
  exit 1
fi

printf 'PASS stow sync keeps runtime directories local and supports repeated runs\n'
