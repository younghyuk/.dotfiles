#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'usage: %s <source-agents-dir> <target-agents-dir>\n' "$0" >&2
  exit 2
fi

SOURCE_DIR="$1"
TARGET_DIR="$2"

if [[ ! -d "$SOURCE_DIR" ]]; then
  printf 'Codex agent source directory missing: %s\n' "$SOURCE_DIR" >&2
  exit 1
fi

if [[ -L "$TARGET_DIR" ]]; then
  printf 'Codex agent target must be a machine-local directory: %s\n' "$TARGET_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

if [[ ! -d "$TARGET_DIR" ]]; then
  printf 'Codex agent target is not a directory: %s\n' "$TARGET_DIR" >&2
  exit 1
fi

shopt -s nullglob
ROLE_SOURCES=("$SOURCE_DIR"/*.toml)

if [[ ${#ROLE_SOURCES[@]} -eq 0 ]]; then
  printf 'No Codex agent role files found: %s\n' "$SOURCE_DIR" >&2
  exit 1
fi

TEMPORARY_FILE=''

clean_temporary_file() {
  if [[ -n "$TEMPORARY_FILE" && -e "$TEMPORARY_FILE" ]]; then
    unlink "$TEMPORARY_FILE"
  fi
}

trap clean_temporary_file EXIT

for role_source in "${ROLE_SOURCES[@]}"; do
  if [[ ! -f "$role_source" || -L "$role_source" ]]; then
    printf 'Codex agent source must be a regular file: %s\n' "$role_source" >&2
    exit 1
  fi

  role_name="${role_source##*/}"
  role_target="$TARGET_DIR/$role_name"

  if [[ -L "$role_target" ]]; then
    unlink "$role_target"
  elif [[ -e "$role_target" && ! -f "$role_target" ]]; then
    printf 'Codex agent target collides with a non-file path: %s\n' "$role_target" >&2
    exit 1
  fi

  if [[ -f "$role_target" ]] && cmp -s "$role_source" "$role_target"; then
    chmod 600 "$role_target"
    printf 'Codex agent already synchronized: %s\n' "$role_name"
    continue
  fi

  TEMPORARY_FILE="$(mktemp "$TARGET_DIR/.${role_name}.XXXXXX")"
  install -m 600 "$role_source" "$TEMPORARY_FILE"
  mv -f "$TEMPORARY_FILE" "$role_target"
  TEMPORARY_FILE=''
  printf 'Codex agent synchronized: %s\n' "$role_name"
done
