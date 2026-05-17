#!/usr/bin/env bash
# 새 머신 셋업 시 한 번 실행: bash ~/.dotfiles/claude/setup-mcp.sh

set -e

echo "MCP 서버 등록 중..."

claude mcp add mysql_seoul4pm_local -s user \
  -e MYSQL_HOST=127.0.0.1 \
  -e MYSQL_PORT=3306 \
  -e MYSQL_USER=root \
  -e MYSQL_PASS='4pm!234' \
  -e MYSQL_DB=seoul4pm \
  -- npx -y @benborla29/mcp-server-mysql

claude mcp add github -s user \
  -e GITHUB_PERSONAL_ACCESS_TOKEN="op://Personal/GitHub PAT - Claude/credential" \
  -- op run -- npx -y @modelcontextprotocol/server-github

claude mcp add context7 -s user \
  -- npx -y @upstash/context7-mcp

claude mcp add playwright -s user \
  -- npx @playwright/mcp@latest

claude mcp add --transport http linear -s user \
  https://mcp.linear.app/sse

echo "완료. 등록된 MCP 서버:"
claude mcp list
