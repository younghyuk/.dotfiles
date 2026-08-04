#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC_SCRIPT="$DOTFILES_DIR/scripts/agent-instructions-sync.sh"
TEST_ROOT="$(mktemp -d /tmp/dotfiles-agent-instructions-test.XXXXXX)"
EXPECTED_TARGET="../.agents/AGENTS.md"

clean_test_root() {
  case "$TEST_ROOT" in
    /tmp/dotfiles-agent-instructions-test.*)
      find "$TEST_ROOT" -depth -delete
      ;;
    *)
      printf 'FAIL refusing to clean unexpected path: %s\n' "$TEST_ROOT" >&2
      return 1
      ;;
  esac
}

prepare_test_home() {
  local target_home="$1"

  mkdir -p "$target_home/.agents"
  cp "$DOTFILES_DIR/agents/.agents/AGENTS.md" "$target_home/.agents/AGENTS.md"
}

assert_instruction_link() {
  local link_path="$1"
  local canonical_path="$2"

  [[ -L "$link_path" ]]
  [[ "$(readlink "$link_path")" == "$EXPECTED_TARGET" ]]
  [[ "$(realpath "$link_path")" == "$(realpath "$canonical_path")" ]]
}

trap clean_test_root EXIT

fresh_home="$TEST_ROOT/fresh-home"
prepare_test_home "$fresh_home"

bash "$SYNC_SCRIPT" "$fresh_home" "$fresh_home/.agents/AGENTS.md"
bash "$SYNC_SCRIPT" "$fresh_home" "$fresh_home/.agents/AGENTS.md"

assert_instruction_link "$fresh_home/.codex/AGENTS.md" "$fresh_home/.agents/AGENTS.md"
assert_instruction_link "$fresh_home/.claude/CLAUDE.md" "$fresh_home/.agents/AGENTS.md"
[[ ! -e "$fresh_home/.codex/AGENTS.md.before-dotfiles-sync.bak" ]]
[[ ! -e "$fresh_home/.claude/CLAUDE.md.before-dotfiles-sync.bak" ]]

upgrade_home="$TEST_ROOT/upgrade-home"
prepare_test_home "$upgrade_home"
mkdir -p "$upgrade_home/.codex" "$upgrade_home/.claude"
touch "$upgrade_home/.codex/AGENTS.md"
cp "$DOTFILES_DIR/agents/.agents/AGENTS.md" "$upgrade_home/.claude/CLAUDE.md"

bash "$SYNC_SCRIPT" "$upgrade_home" "$upgrade_home/.agents/AGENTS.md"
bash "$SYNC_SCRIPT" "$upgrade_home" "$upgrade_home/.agents/AGENTS.md"

assert_instruction_link "$upgrade_home/.codex/AGENTS.md" "$upgrade_home/.agents/AGENTS.md"
assert_instruction_link "$upgrade_home/.claude/CLAUDE.md" "$upgrade_home/.agents/AGENTS.md"
[[ -f "$upgrade_home/.codex/AGENTS.md.before-dotfiles-sync.bak" ]]
[[ -f "$upgrade_home/.claude/CLAUDE.md.before-dotfiles-sync.bak" ]]
[[ ! -s "$upgrade_home/.codex/AGENTS.md.before-dotfiles-sync.bak" ]]
cmp -s \
  "$DOTFILES_DIR/agents/.agents/AGENTS.md" \
  "$upgrade_home/.claude/CLAUDE.md.before-dotfiles-sync.bak"

foreign_canonical_home="$TEST_ROOT/foreign-canonical-home"
mkdir -p "$foreign_canonical_home/.agents"
printf 'foreign instructions\n' >"$foreign_canonical_home/.agents/AGENTS.md"

if foreign_output="$(bash "$SYNC_SCRIPT" "$foreign_canonical_home" \
  "$DOTFILES_DIR/agents/.agents/AGENTS.md" 2>&1)"; then
  printf 'FAIL foreign canonical instructions were accepted\n' >&2
  exit 1
fi

[[ "$foreign_output" == *'canonical agent instructions point outside the dotfiles repo'* ]]
[[ ! -e "$foreign_canonical_home/.codex/AGENTS.md" ]]
[[ ! -e "$foreign_canonical_home/.claude/CLAUDE.md" ]]

conflict_home="$TEST_ROOT/conflict-home"
prepare_test_home "$conflict_home"
mkdir -p "$conflict_home/.codex" "$conflict_home/foreign"
cp "$DOTFILES_DIR/agents/.agents/AGENTS.md" "$conflict_home/foreign/AGENTS.md"
ln -s ../foreign/AGENTS.md "$conflict_home/.codex/AGENTS.md"

if conflict_output="$(bash "$SYNC_SCRIPT" "$conflict_home" \
  "$conflict_home/.agents/AGENTS.md" 2>&1)"; then
  printf 'FAIL foreign instruction link was overwritten\n' >&2
  exit 1
fi

[[ "$conflict_output" == *'instruction link points elsewhere'* ]]
[[ "$(readlink "$conflict_home/.codex/AGENTS.md")" == ../foreign/AGENTS.md ]]
[[ ! -e "$conflict_home/.claude/CLAUDE.md" ]]

printf 'PASS agent instruction sync creates, migrates, and protects shared links\n'
