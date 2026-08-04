#!/usr/bin/env bash

set -u

if [[ $# -ne 2 ]]; then
  printf 'usage: %s <target-home> <expected-canonical-path>\n' "$0" >&2
  exit 2
fi

TARGET_HOME="$1"
EXPECTED_CANONICAL_PATH="$2"
CANONICAL_PATH="$TARGET_HOME/.agents/AGENTS.md"
EXPECTED_TARGET="../.agents/AGENTS.md"
INSTRUCTION_PATHS=(
  "$TARGET_HOME/.codex/AGENTS.md"
  "$TARGET_HOME/.claude/CLAUDE.md"
)

validate_instruction_path() {
  local instruction_path="$1"
  local instruction_directory="${instruction_path%/*}"
  local backup_path="${instruction_path}.before-dotfiles-sync.bak"

  if [[ -L "$instruction_directory" ]]; then
    printf 'FAIL instruction directory must be local: %s\n' "$instruction_directory" >&2
    return 1
  fi
  if [[ -e "$instruction_directory" && ! -d "$instruction_directory" ]]; then
    printf 'FAIL instruction parent is not a directory: %s\n' "$instruction_directory" >&2
    return 1
  fi
  if [[ -L "$instruction_path" ]]; then
    if [[ "$(readlink "$instruction_path")" == "$EXPECTED_TARGET" ]]; then
      return
    fi
    printf 'FAIL instruction link points elsewhere: %s -> %s\n' \
      "$instruction_path" "$(readlink "$instruction_path")" >&2
    return 1
  fi
  if [[ ! -e "$instruction_path" ]]; then
    return
  fi
  if [[ ! -f "$instruction_path" ]]; then
    printf 'FAIL instruction path is not a regular file: %s\n' "$instruction_path" >&2
    return 1
  fi
  if [[ -e "$backup_path" || -L "$backup_path" ]]; then
    printf 'FAIL instruction backup already exists: %s\n' "$backup_path" >&2
    return 1
  fi
}

sync_instruction_path() {
  local instruction_path="$1"
  local instruction_directory="${instruction_path%/*}"
  local backup_path="${instruction_path}.before-dotfiles-sync.bak"

  mkdir -p "$instruction_directory"

  if [[ -L "$instruction_path" ]]; then
    printf 'PASS instruction link already synchronized: %s\n' "$instruction_path"
    return
  fi
  if [[ -f "$instruction_path" ]]; then
    if ! mv "$instruction_path" "$backup_path"; then
      printf 'FAIL could not back up instruction file: %s\n' "$instruction_path" >&2
      return 1
    fi
    printf 'WARN instruction file backed up: %s\n' "$backup_path"
  fi
  if ln -s "$EXPECTED_TARGET" "$instruction_path"; then
    printf 'PASS instruction link synchronized: %s -> %s\n' \
      "$instruction_path" "$EXPECTED_TARGET"
  else
    printf 'FAIL could not create instruction link: %s\n' "$instruction_path" >&2
    return 1
  fi
}

if ! command -v realpath >/dev/null 2>&1; then
  printf 'FAIL realpath is required to validate agent instructions\n' >&2
  exit 1
fi
if [[ ! -f "$EXPECTED_CANONICAL_PATH" ]]; then
  printf 'FAIL expected canonical agent instructions missing: %s\n' \
    "$EXPECTED_CANONICAL_PATH" >&2
  exit 1
fi
if [[ ! -f "$CANONICAL_PATH" ]]; then
  printf 'FAIL canonical agent instructions missing: %s\n' "$CANONICAL_PATH" >&2
  exit 1
fi
if [[ "$(realpath "$CANONICAL_PATH")" != "$(realpath "$EXPECTED_CANONICAL_PATH")" ]]; then
  printf 'FAIL canonical agent instructions point outside the dotfiles repo: %s -> %s\n' \
    "$CANONICAL_PATH" "$(realpath "$CANONICAL_PATH")" >&2
  exit 1
fi

VALIDATION_FAILURES=0
for instruction_path in "${INSTRUCTION_PATHS[@]}"; do
  if ! validate_instruction_path "$instruction_path"; then
    VALIDATION_FAILURES=$((VALIDATION_FAILURES + 1))
  fi
done
if [[ $VALIDATION_FAILURES -gt 0 ]]; then
  exit 1
fi

SYNC_FAILURES=0
for instruction_path in "${INSTRUCTION_PATHS[@]}"; do
  if ! sync_instruction_path "$instruction_path"; then
    SYNC_FAILURES=$((SYNC_FAILURES + 1))
  fi
done

if [[ $SYNC_FAILURES -gt 0 ]]; then
  exit 1
fi
