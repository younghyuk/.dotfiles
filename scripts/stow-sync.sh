#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'usage: %s <stow-dir> <target-home>\n' "$0" >&2
  exit 2
fi

STOW_DIR="$1"
TARGET_HOME="$2"

if ! command -v stow >/dev/null 2>&1; then
  printf 'stow missing: brew install stow\n' >&2
  exit 1
fi
if [[ ! -d "$STOW_DIR" ]]; then
  printf 'stow directory missing: %s\n' "$STOW_DIR" >&2
  exit 1
fi
if [[ ! -d "$TARGET_HOME" ]]; then
  printf 'target home missing: %s\n' "$TARGET_HOME" >&2
  exit 1
fi

stow --dir="$STOW_DIR" --target="$TARGET_HOME" --restow agents
stow --dir="$STOW_DIR" --target="$TARGET_HOME" --restow --no-folding codex claude gcloud zsh 1password ssh
