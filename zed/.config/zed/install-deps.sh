#!/usr/bin/env zsh
cd "$ZED_WORKTREE_ROOT"

if [[ -f pnpm-lock.yaml ]]; then
  pnpm install
elif [[ -f yarn.lock ]]; then
  yarn install
elif [[ -f package-lock.json ]]; then
  npm install
fi
