#!/usr/bin/env bash
# Compare the live Codex config with the portable template while ignoring the
# machine-managed state preserved by codex-config-sync.py.
#
# Exit codes: 0 = in sync, 1 = drift found, 2 = error.

set -u

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$DOTFILES_DIR/codex/.codex/config.template.toml"
LIVE="${1:-$HOME/.codex/config.toml}"
SYNC_SCRIPT="$DOTFILES_DIR/scripts/codex-config-sync.py"

if ! command -v uv >/dev/null 2>&1; then
  echo 'uv missing: brew install uv' >&2
  exit 2
fi

exec uv run --script "$SYNC_SCRIPT" \
  --template "$TEMPLATE" \
  --live "$LIVE" \
  --check
