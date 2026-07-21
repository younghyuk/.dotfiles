#!/usr/bin/env bash

set -u

STATUS=0
MCP_NAMES="$(claude mcp list 2>/dev/null | awk '{print $1}' | sed 's/:$//')"

has_mcp() {
  printf '%s\n' "$MCP_NAMES" | grep -Fxq "$1"
}

add_mcp_if_missing() {
  local name="$1"
  shift

  if has_mcp "$name"; then
    printf 'PASS claude mcp %s already exists\n' "$name"
    return
  fi

  if claude mcp add "$name" "$@"; then
    printf 'PASS claude mcp %s added\n' "$name"
  else
    STATUS=1
    printf 'FAIL claude mcp %s add failed\n' "$name"
  fi
}

add_mcp_if_missing github -s user --transport http https://api.githubcopilot.com/mcp/ \
  --header "Authorization: Bearer \${GITHUB_MCP_PAT}"

add_mcp_if_missing context7 -s user \
  -- npx -y @upstash/context7-mcp

add_mcp_if_missing playwright -s user \
  -- npx @playwright/mcp@latest

# GA4 읽기전용 (서비스계정). 키는 1Password → ~/.config/gcloud/ga-sa-key.json (bootstrap.sh).
# 여기엔 키 경로+프로젝트id 만 — 비밀 아님.
add_mcp_if_missing analytics-mcp -s user \
  -e "GOOGLE_APPLICATION_CREDENTIALS=$HOME/.config/gcloud/ga-sa-key.json" \
  -e "GOOGLE_PROJECT_ID=seoul4pm-459908" \
  -- uvx analytics-mcp

exit "$STATUS"
