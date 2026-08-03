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

remove_user_mcp_if_present() {
  local name="$1"
  local details
  details="$(claude mcp get "$name" 2>/dev/null || true)"

  if ! printf '%s\n' "$details" | grep -Fq 'Scope: User config'; then
    printf 'PASS claude user mcp %s absent\n' "$name"
    return
  fi

  if claude mcp remove "$name" -s user; then
    printf 'PASS claude user mcp %s removed\n' "$name"
  else
    STATUS=1
    printf 'FAIL claude user mcp %s removal failed\n' "$name"
  fi
}

# Google Analytics is project-scoped and uses adc-ga-reader.json from each
# repo's .mcp.json. Remove the obsolete user entry that pointed at ga-sa-key.json.
remove_user_mcp_if_present analytics-mcp

add_mcp_if_missing github -s user --transport http https://api.githubcopilot.com/mcp/ \
  --header "Authorization: Bearer \${GITHUB_MCP_PAT}"

add_mcp_if_missing context7 -s user \
  -- npx -y @upstash/context7-mcp

add_mcp_if_missing playwright -s user \
  -- npx @playwright/mcp@latest

# PostHog (remote HTTP). 첫 사용 시 브라우저 OAuth 로그인(사전 키 불필요, US/EU 자동 라우팅).
# 스토어프론트 애널리틱스 파일럿 데이터 조회용(project 531529).
add_mcp_if_missing posthog -s user --transport http https://mcp.posthog.com/mcp

exit "$STATUS"
