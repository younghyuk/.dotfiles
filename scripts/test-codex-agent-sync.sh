#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC_SCRIPT="$DOTFILES_DIR/scripts/codex-agent-sync.sh"
TEST_ROOT="$(mktemp -d /tmp/dotfiles-codex-agent-sync-test.XXXXXX)"
SOURCE_DIR="$TEST_ROOT/source"
TARGET_DIR="$TEST_ROOT/home/.codex/agents"
LEGACY_SOURCE="$TEST_ROOT/legacy-code-explorer.toml"

clean_test_root() {
  case "$TEST_ROOT" in
    /tmp/dotfiles-codex-agent-sync-test.*)
      find "$TEST_ROOT" -depth -delete
      ;;
    *)
      printf 'FAIL refusing to clean unexpected path: %s\n' "$TEST_ROOT" >&2
      return 1
      ;;
  esac
}

file_mode() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

assert_regular_copy() {
  local source_file="$1"
  local target_file="$2"

  [[ -f "$target_file" && ! -L "$target_file" ]]
  cmp -s "$source_file" "$target_file"
  [[ "$(file_mode "$target_file")" == 600 ]]
}

trap clean_test_root EXIT
mkdir -p "$SOURCE_DIR" "$TARGET_DIR"

printf '%s\n' 'name = "code_explorer"' >"$SOURCE_DIR/code_explorer.toml"
printf '%s\n' 'name = "reviewer"' >"$SOURCE_DIR/reviewer.toml"
printf '%s\n' 'legacy content' >"$LEGACY_SOURCE"
printf '%s\n' 'local custom role' >"$TARGET_DIR/local_specialist.toml"
ln -s "$LEGACY_SOURCE" "$TARGET_DIR/code_explorer.toml"

bash "$SYNC_SCRIPT" "$SOURCE_DIR" "$TARGET_DIR"

assert_regular_copy "$SOURCE_DIR/code_explorer.toml" "$TARGET_DIR/code_explorer.toml"
assert_regular_copy "$SOURCE_DIR/reviewer.toml" "$TARGET_DIR/reviewer.toml"
[[ "$(cat "$LEGACY_SOURCE")" == 'legacy content' ]]
[[ "$(cat "$TARGET_DIR/local_specialist.toml")" == 'local custom role' ]]

bash "$SYNC_SCRIPT" "$SOURCE_DIR" "$TARGET_DIR"

assert_regular_copy "$SOURCE_DIR/code_explorer.toml" "$TARGET_DIR/code_explorer.toml"
assert_regular_copy "$SOURCE_DIR/reviewer.toml" "$TARGET_DIR/reviewer.toml"
[[ "$(cat "$TARGET_DIR/local_specialist.toml")" == 'local custom role' ]]

COLLISION_TARGET="$TEST_ROOT/collision-home/.codex/agents"
mkdir -p "$COLLISION_TARGET/reviewer.toml"

if bash "$SYNC_SCRIPT" "$SOURCE_DIR" "$COLLISION_TARGET"; then
  printf 'FAIL directory collision should stop synchronization\n' >&2
  exit 1
fi

[[ -d "$COLLISION_TARGET/reviewer.toml" ]]

printf 'PASS Codex agent sync creates portable regular files and preserves local roles\n'
